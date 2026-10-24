//----------------------------------------------------------------
//  ModBrowser.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Cached the website's thumbnails and fetched a mod's description
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// The Mods screen of the title as the game script uses it: the mods of the website and of the
/// relay's catalog with how each stands in the Patch folder, fetched again whenever asked, and one
/// action at a time that installs, updates or removes some of them. Both run on threads of their
/// own, and the game script reads how they stand.
/// </summary>
internal sealed class ModBrowser
{
    /// <summary>
    /// Why the relay's mods are missing from the list.
    /// </summary>
    private const string RelayUnreadable = "The relay's mod list could not be read.";

    /// <summary>
    /// The state of an action that runs.
    /// </summary>
    private const string Busy = "busy";

    /// <summary>
    /// Asks to install a mod, update it, or overwrite a changed copy.
    /// </summary>
    private const string InstallVerb = "install";

    /// <summary>
    /// Asks to remove an installed mod.
    /// </summary>
    private const string RemoveVerb = "remove";

    /// <summary>
    /// What the id of a mod of the website starts with, before its slug.
    /// </summary>
    private const string SitePrefix = "site:";

    /// <summary>
    /// The most lines of a description handed out.
    /// </summary>
    private const int MaxDescriptionLines = 60;

    /// <summary>
    /// The most characters a line of a description keeps.
    /// </summary>
    private const int MaxDescriptionLineLength = 400;

    /// <summary>
    /// The hosts a mod's page may be opened on.
    /// </summary>
    private static readonly string[] PageHosts = [SiteDownload.Host, "github.com"];

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// Lets one scan of the Patch folder run at a time, so the one that ends last read the folder last.
    /// </summary>
    private readonly object _scanGate = new();

    /// <summary>
    /// Whether the mods are being fetched.
    /// </summary>
    private bool _loading;

    /// <summary>
    /// Whether a fetch ended, so a list still missing means it failed.
    /// </summary>
    private bool _fetched;

    /// <summary>
    /// The website's mods as last fetched, <see langword="null"/> before one arrived.
    /// </summary>
    private IReadOnlyList<SiteMod>? _site;

    /// <summary>
    /// The relay catalog's mods as last fetched, <see langword="null"/> before one arrived.
    /// </summary>
    private IReadOnlyList<CatalogMod>? _relay;

    /// <summary>
    /// Why the website's mods could not be fetched the last time.
    /// </summary>
    private string? _siteError;

    /// <summary>
    /// Why the relay's mods could not be fetched the last time.
    /// </summary>
    private string? _relayError;

    /// <summary>
    /// The mods made of the last fetched sources, <see langword="null"/> before one arrived.
    /// </summary>
    private IReadOnlyList<BrowsedMod>? _mods;

    /// <summary>
    /// The mods with how each stood in the Patch folder at the last scan, <see langword="null"/> before the first.
    /// </summary>
    private Listing? _listed;

    /// <summary>
    /// The running or last action's state: "busy", "done" or "failed"; <see langword="null"/> before the first.
    /// </summary>
    private string? _action;

    /// <summary>
    /// Why the last action failed.
    /// </summary>
    private string? _actionError;

    /// <summary>
    /// What the last action did, for the player.
    /// </summary>
    private string? _done;

    /// <summary>
    /// Whether an action changed the Patch folder since the game started, which only a restart loads.
    /// </summary>
    private bool _restart;

    /// <summary>
    /// Whether thumbnails are being cached.
    /// </summary>
    private bool _thumbnailing;

    /// <summary>
    /// Whether a fetch ended while thumbnails were being cached, so they are cached again for its list.
    /// </summary>
    private bool _thumbnailsAgain;

    /// <summary>
    /// The cached thumbnails' paths relative to the game's folder, by their addresses.
    /// </summary>
    private Dictionary<string, string> _thumbnails = new(StringComparer.Ordinal);

    /// <summary>
    /// The plain lines of each fetched description, by its mod's id.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<string>> _descriptions = new(StringComparer.Ordinal);

    /// <summary>
    /// The ids of the mods whose descriptions are being fetched, the one asked for last at the end.
    /// </summary>
    private readonly List<string> _describing = [];

    /// <summary>
    /// The game's mod browser, which the game script uses.
    /// </summary>
    public static ModBrowser Current { get; } = new();

    /// <summary>
    /// The key the website's list must be signed with; tests sign with a key of their own.
    /// </summary>
    public FeedKey SiteKey { get; init; } = SiteFeed.PinnedKey;

    /// <summary>
    /// Fetches the website's mods and checks their signature with a key; tests replace it, since they cannot reach the website.
    /// </summary>
    public Func<FeedKey, IReadOnlyList<SiteMod>> FetchSite { get; init; } = SiteFeed.Fetch;

    /// <summary>
    /// Fetches the relay's mod catalog; tests replace it.
    /// </summary>
    public Func<ModCatalog> FetchRelay { get; init; } = () => RelayClient().Mods();

    /// <summary>
    /// Downloads a mod of the website by its address and the SHA-256 of its file; tests replace it.
    /// </summary>
    public Func<string, string, byte[]> DownloadSite { get; init; } = SiteDownload.Get;

    /// <summary>
    /// Fetches the description of a mod of the website by its slug and checks its signature with a key; tests replace it.
    /// </summary>
    public Func<FeedKey, string, string> FetchDescription { get; init; } = SiteFeed.FetchDescription;

    /// <summary>
    /// Downloads a mod's thumbnail from the website by its address; tests replace it.
    /// </summary>
    public Func<string, byte[]> DownloadThumbnail { get; init; } = ModThumbnails.Download;

    /// <summary>
    /// Downloads a link mod's release file from GitHub; tests replace it.
    /// </summary>
    public Func<string, byte[]> DownloadRelease { get; init; } = ReleaseDownload.Get;

    /// <summary>
    /// Downloads an uploaded mod's zip from the relay by the mod's key; tests replace it.
    /// </summary>
    public Func<string, byte[]> DownloadUpload { get; init; } = key => RelayClient().ModFile(key);

    /// <summary>
    /// The game's folder, which holds Patch; tests point it elsewhere.
    /// </summary>
    public Func<string> GameFolder { get; init; } = () => ModFolder.GamePathOf(".");

    /// <summary>
    /// Opens an address in the player's browser; tests replace it.
    /// </summary>
    public Action<string> OpenUrl { get; init; } = url =>
    {
        using var _ = Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
    };

    /// <summary>
    /// Fetches the website's and the relay's mods again and scans the Patch folder, unless they are
    /// being fetched already, then caches the thumbnails of the list.
    /// </summary>
    /// <returns><see langword="false"/> while a fetch runs.</returns>
    public bool Refresh()
    {
        lock (_gate)
        {
            if (_loading)
            {
                return false;
            }

            _loading = true;
        }

        Threads.Start("MultiplayerModBrowser", () =>
        {
            try
            {
                Fetch();
                Scan();
                StartThumbnails();
            }
            catch (Exception ex)
            {
                Log.Write($"mod browser: the fetch failed: {ex}");
            }
            finally
            {
                lock (_gate)
                {
                    _loading = false;
                    _fetched = true;
                }
            }
        });

        return true;
    }

    /// <summary>
    /// Describes the mods and the last action for the game script.
    /// </summary>
    /// <returns>
    /// <c>state</c> ("idle", "loading", "ready" or "failed"), <c>error</c> (why a source failed),
    /// <c>updates</c> (how many mods have an update), <c>action</c> ("idle", "busy", "done" or "failed"),
    /// <c>action_error</c>, <c>done</c> (what the last action did), <c>restart</c> (1 once an action
    /// changed the Patch folder) and <c>loading_details</c> (the id of the mod whose description is
    /// being fetched, the one asked for last), then one line per mod, updates first, then changed,
    /// current and available mods, each by name: <c>mod</c>, id, name, author, status (see
    /// <see cref="ModStatus"/>), installed version, latest version, source (see <see cref="ModSource"/>),
    /// page, file count, size in bytes, summary, thumbnail (the cached PNG's path relative to the game's
    /// folder, empty until it is there), spoiler (1 or empty); after it one line <c>note</c>, id, line,
    /// per line of its changelog, then one line <c>desc</c>, id, line, per line of its fetched
    /// description; each separated by tabs.
    /// </returns>
    public string Describe()
    {
        lock (_gate)
        {
            var state = _loading ? "loading" : _listed != null ? "ready" : _fetched ? "failed" : "idle";
            var errors = string.Join(" ", new[] { _siteError, _relayError }.OfType<string>());
            var headers = new KeyValuePair<string, string?>[]
            {
                new("state", state),
                new("error", errors),
                new("updates", (_listed?.States.Values.Count(mod => mod.Status == ModStatus.Update) ?? 0).ToString(CultureInfo.InvariantCulture)),
                new("action", _action ?? "idle"),
                new("action_error", _action == "failed" ? _actionError : null),
                new("done", _action is "done" or "failed" ? _done : null),
                new("restart", _restart ? "1" : null),
                new("loading_details", _describing.Count > 0 ? _describing[^1] : null),
            };

            return new Message(headers, _listed is { } listed ? ListText(listed, _thumbnails, _descriptions) : string.Empty).Encode();
        }
    }

    /// <summary>
    /// Installs and removes mods of the list as last scanned, as one action on a thread of its own,
    /// then scans the Patch folder again.
    /// </summary>
    /// <param name="lines">Each mod's id, after <c>install</c> to install, update or overwrite it, or <c>remove</c> to remove its installed version.</param>
    /// <returns><see langword="false"/> while an action runs, before the first list, or for a mod the list lacks or one not installed to remove.</returns>
    public bool Apply(IReadOnlyList<(string Verb, string Id)> lines)
    {
        var installs = new List<BrowsedMod>();
        var removes = new List<(BrowsedMod Mod, ModVersion Installed)>();
        IReadOnlySet<string> kept;

        lock (_gate)
        {
            if (Refusal(lines, installs, removes) is { } why)
            {
                Log.Write($"mod browser: action refused: {why}");
                return false;
            }

            kept = FilesOfOthers(_listed!, installs.Select(mod => mod.Id).Concat(removes.Select(remove => remove.Mod.Id)).ToHashSet());
            _action = Busy;
            _actionError = null;
            _done = null;
        }

        Threads.Start("MultiplayerModBrowserAction", () => Run(installs, removes, kept));
        return true;
    }

    /// <summary>
    /// Starts fetching the description of a mod of the website on a thread of its own, unless it is
    /// known or being fetched already; a failed fetch may be started again.
    /// </summary>
    /// <param name="id">The mod's id.</param>
    /// <returns>Whether it started or is known or being fetched; <see langword="false"/> for a mod the list lacks or one not of the website.</returns>
    public bool Details(string id)
    {
        lock (_gate)
        {
            var mod = _listed?.Mods.FirstOrDefault(mod => mod.Id == id);

            if (mod?.Source != ModSource.Site || !id.StartsWith(SitePrefix, StringComparison.Ordinal))
            {
                Log.Write($"mod browser: description of {id} not fetched: {(mod == null ? "the list has no such mod" : $"it is a mod of the {mod.Source}")}");
                return false;
            }

            if (_descriptions.ContainsKey(id) || _describing.Contains(id))
            {
                return true;
            }

            _describing.Add(id);
        }

        Threads.Start("MultiplayerModDetails", () => FetchDetails(id, id[SitePrefix.Length..]));
        return true;
    }

    /// <summary>
    /// Opens a mod's page in the player's browser, if it is on the website or on GitHub.
    /// </summary>
    /// <param name="id">The mod's id.</param>
    /// <returns>Whether it was opened.</returns>
    public bool OpenPage(string id)
    {
        string? page;

        lock (_gate)
        {
            page = _listed?.Mods.FirstOrDefault(mod => mod.Id == id)?.Page;
        }

        if (!Uri.TryCreate(page, UriKind.Absolute, out var url) || url.Scheme != Uri.UriSchemeHttps || !PageHosts.Contains(url.Host, StringComparer.OrdinalIgnoreCase))
        {
            Log.Write($"mod browser: page of {id} not opened: {(page is { Length: > 0 } ? $"{page} is not on the website or GitHub" : "it has none")}");
            return false;
        }

        OpenUrl(url.AbsoluteUri);
        Log.Write($"mod browser: opened {url.AbsoluteUri}");
        return true;
    }

    /// <summary>
    /// Fetches both sources and makes the mods of them, keeping a source's last mods when it fails.
    /// </summary>
    private void Fetch()
    {
        IReadOnlyList<SiteMod>? site = null;
        IReadOnlyList<CatalogMod>? relay = null;
        string? siteError = null;
        string? relayError = null;

        try
        {
            site = FetchSite(SiteKey);
        }
        catch (SiteFeedException ex)
        {
            siteError = ex.Message;
        }
        catch (Exception ex)
        {
            Log.Write($"mod browser: the website's mod list failed: {ex.GetBaseException().Message}");
            siteError = SiteFeed.Unreachable;
        }

        try
        {
            relay = FetchRelay().Mods;
        }
        catch (Exception ex)
        {
            Log.Write($"mod browser: the relay's mod list failed: {ex.GetBaseException().Message}");
            relayError = RelayUnreadable;
        }

        Log.Write($"mod browser: the website lists {(site != null ? $"{site.Count} mod(s)" : $"nothing: {siteError}")}, the relay {(relay != null ? $"{relay.Count} mod(s)" : $"nothing: {relayError}")}");

        lock (_gate)
        {
            _site = site ?? _site;
            _relay = relay ?? _relay;
            _siteError = siteError;
            _relayError = relayError;
            site = _site;
            relay = _relay;
        }

        if (site == null && relay == null)
        {
            return;
        }

        var mods = ModMerge.Merge(site, relay);

        lock (_gate)
        {
            _mods = mods;
        }
    }

    /// <summary>
    /// Fetches a mod's description and keeps it as plain lines, or logs why it failed.
    /// </summary>
    /// <param name="id">The mod's id.</param>
    /// <param name="slug">Its slug on the website.</param>
    private void FetchDetails(string id, string slug)
    {
        IReadOnlyList<string>? lines = null;

        try
        {
            lines = MarkdownText.Lines(FetchDescription(SiteKey, slug), MaxDescriptionLines, MaxDescriptionLineLength);
            Log.Write($"mod browser: the description of {id} has {lines.Count} line(s)");
        }
        catch (SiteFeedException ex)
        {
            Log.Write($"mod browser: the description of {id} failed: {ex.Message}");
        }
        catch (Exception ex)
        {
            Log.Write($"mod browser: the description of {id} failed: {ex}");
        }
        finally
        {
            lock (_gate)
            {
                _describing.Remove(id);

                if (lines != null)
                {
                    _descriptions[id] = lines;
                }
            }
        }
    }

    /// <summary>
    /// Caches the thumbnails of the list on a thread of its own, or once more after the run that caches them now.
    /// </summary>
    private void StartThumbnails()
    {
        lock (_gate)
        {
            if (_thumbnailing)
            {
                _thumbnailsAgain = true;
                return;
            }

            _thumbnailing = true;
        }

        Threads.Start("MultiplayerModThumbnails", () =>
        {
            do
            {
                try
                {
                    CacheThumbnails();
                }
                catch (Exception ex)
                {
                    Log.Write($"mod browser: caching the thumbnails failed: {ex}");
                }
            }
            while (ThumbnailsAgain());
        });
    }

    /// <summary>
    /// Tells whether a fetch ended while the thumbnails were being cached, and else ends caching them.
    /// </summary>
    /// <returns>Whether to cache them once more.</returns>
    private bool ThumbnailsAgain()
    {
        lock (_gate)
        {
            _thumbnailing = _thumbnailsAgain;
            _thumbnailsAgain = false;
            return _thumbnailing;
        }
    }

    /// <summary>
    /// Takes the cached thumbnails of the list, deletes the others and downloads the missing ones one at a time.
    /// </summary>
    /// <remarks>
    /// A failed download leaves its thumbnail out until the next refresh tries again.
    /// </remarks>
    private void CacheThumbnails()
    {
        List<string> urls;

        lock (_gate)
        {
            if (_listed is not { } listed)
            {
                return;
            }

            urls = listed.Mods.Select(mod => mod.Thumbnail?.Url).OfType<string>().Distinct(StringComparer.Ordinal).ToList();
        }

        var game = GameFolder();
        var cached = urls.Where(url => File.Exists(Path.Combine(game, ModThumbnails.PathOf(url)))).ToDictionary(url => url, ModThumbnails.PathOf, StringComparer.Ordinal);

        lock (_gate)
        {
            _thumbnails = new Dictionary<string, string>(cached, StringComparer.Ordinal);
        }

        ModThumbnails.Prune(game, urls);
        var missing = urls.Where(url => !cached.ContainsKey(url)).ToList();
        Log.Write($"mod browser: {cached.Count} thumbnail(s) cached, {missing.Count} to download");

        foreach (var url in missing)
        {
            try
            {
                var path = ModThumbnails.Store(game, url, DownloadThumbnail(url));

                lock (_gate)
                {
                    _thumbnails[url] = path;
                }

                Log.Write($"mod browser: thumbnail {url} cached as {path}");
            }
            catch (Exception ex)
            {
                Log.Write($"mod browser: thumbnail {url} not cached: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Reads how each mod stands in the Patch folder, after deleting the DLLs an install renamed out of the way.
    /// </summary>
    private void Scan()
    {
        lock (_scanGate)
        {
            IReadOnlyList<BrowsedMod>? mods;

            lock (_gate)
            {
                mods = _mods;
            }

            if (mods == null)
            {
                return;
            }

            var patch = PatchFolder();
            PatchScan.DeleteOldDlls(patch);
            var states = PatchScan.Detect(mods, patch);

            lock (_gate)
            {
                _listed = new Listing(mods, states);
            }
        }
    }

    /// <summary>
    /// Tells why an action may not start, and else sorts its mods. Called with <see cref="_gate"/> held.
    /// </summary>
    /// <param name="lines">The action's lines.</param>
    /// <param name="installs">Receives the mods to install.</param>
    /// <param name="removes">Receives the mods to remove, each with its installed version.</param>
    /// <returns>Why not, for the log; <see langword="null"/> when it may start.</returns>
    private string? Refusal(IReadOnlyList<(string Verb, string Id)> lines, List<BrowsedMod> installs, List<(BrowsedMod Mod, ModVersion Installed)> removes)
    {
        if (_action == Busy)
        {
            return "another action runs";
        }

        if (_listed is not { } listed)
        {
            return "the mods have not been fetched yet";
        }

        foreach (var (verb, id) in lines.Distinct())
        {
            var mod = listed.Mods.FirstOrDefault(mod => mod.Id == id);

            if (mod == null)
            {
                return $"the list has no mod {id}";
            }

            if (verb == InstallVerb)
            {
                installs.Add(mod);
            }
            else if (verb == RemoveVerb && listed.States[id].Installed is { } installed)
            {
                removes.Add((mod, installed));
            }
            else
            {
                return verb == RemoveVerb ? $"{id} is {listed.States[id].Status}, no known version of it is installed to remove" : $"{verb} is no action";
            }
        }

        return installs.Count + removes.Count == 0 ? "it names no mod" : null;
    }

    /// <summary>
    /// Names the files of the installed versions of every mod an action leaves alone.
    /// </summary>
    /// <param name="listed">The list the action works on.</param>
    /// <param name="acting">The ids of the mods the action installs or removes.</param>
    /// <returns>Their paths inside Patch.</returns>
    private static HashSet<string> FilesOfOthers(Listing listed, IReadOnlySet<string> acting) =>
        listed.Mods
            .Where(mod => !acting.Contains(mod.Id) && listed.States[mod.Id].Installed != null)
            .SelectMany(mod => listed.States[mod.Id].Installed!.Files.Keys)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Runs an action: installs its mods together, then removes its others, then scans the Patch folder again.
    /// </summary>
    /// <param name="installs">The mods to install.</param>
    /// <param name="removes">The mods to remove, each with its installed version.</param>
    /// <param name="kept">Paths inside Patch that other installed mods ship, which no removal deletes.</param>
    private void Run(List<BrowsedMod> installs, List<(BrowsedMod Mod, ModVersion Installed)> removes, IReadOnlySet<string> kept)
    {
        var said = new List<string>();
        var changed = false;
        string? error = null;

        try
        {
            if (installs.Count > 0)
            {
                Log.Write($"mod browser: installing {string.Join(", ", installs.Select(mod => $"{mod.Id} {mod.Latest} ({mod.Source})"))}");
                var written = ModInstaller.Install(installs.Select(mod => (mod.Install, mod.Target)).ToList(), install => Download(installs.First(mod => ReferenceEquals(mod.Install, install))), GameFolder(), kept);
                changed = true;
                Log.Write($"mod browser: installed {string.Join(", ", installs.Select(mod => $"{mod.Name} {mod.Latest}"))}: {string.Join(", ", written)}");
                said.Add($"Installed {string.Join(", ", installs.Select(mod => $"{mod.Name} {mod.Latest}"))}.");
            }

            var patch = PatchFolder();
            var gone = new List<string>();
            var stuck = new List<string>();

            foreach (var (mod, installed) in removes)
            {
                var (removed, failed) = PatchScan.Remove(mod, installed, patch, kept);
                changed |= removed.Count > 0;
                (failed.Count > 0 ? stuck : gone).Add(mod.Name);
                Log.Write($"mod browser: removed {removed.Count} file(s) of {mod.Name} {installed.Version}{(failed.Count > 0 ? $", {failed.Count} could not be removed" : string.Empty)}");
            }

            if (gone.Count > 0)
            {
                said.Add($"Removed {string.Join(", ", gone)}.");
            }

            if (stuck.Count > 0)
            {
                error = $"Some files of {string.Join(", ", stuck)} could not be removed.";
            }
        }
        catch (Exception ex)
        {
            error = ReasonFor(ex);
            Log.Write($"mod browser: the action failed: {ex.GetBaseException().Message}, the player reads: {error}{(ex is InvalidDataException or InvalidOperationException or IOException or DirectoryException ? string.Empty : $"; {ex}")}");
        }

        try
        {
            Scan();
        }
        catch (Exception ex)
        {
            Log.Write($"mod browser: the scan after the action failed: {ex}");
        }

        lock (_gate)
        {
            _restart |= changed;
            _action = error == null ? "done" : "failed";
            _actionError = error;
            _done = said.Count > 0 ? string.Join(" ", said) : null;
        }

        Log.Write($"mod browser: the action {(error == null ? "is done" : $"failed: {error}")}{(said.Count > 0 ? $"; {string.Join(" ", said)}" : string.Empty)}");
    }

    /// <summary>
    /// Downloads a mod from where it is installed from, and logs its size.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The script or the zip.</returns>
    private byte[] Download(BrowsedMod mod)
    {
        var bytes = mod.Source switch
        {
            ModSource.Site => DownloadSite(mod.Install.FileUrl, mod.PackageHash),
            ModSource.GitHub => DownloadRelease(mod.Install.FileUrl),
            _ => DownloadUpload(mod.Install.Key),
        };

        Log.Write($"mod browser: downloaded {mod.Id} {mod.Latest} from {mod.Source}: {bytes.Length.ToString(CultureInfo.InvariantCulture)} bytes");
        return bytes;
    }

    /// <summary>
    /// The full path of the game's Patch folder.
    /// </summary>
    /// <returns>The path, without a trailing separator.</returns>
    private string PatchFolder() => Path.GetFullPath(Path.Combine(GameFolder(), "Patch"));

    /// <summary>
    /// Makes a client for the relay this version keeps its mod catalog at.
    /// </summary>
    /// <returns>The client.</returns>
    /// <exception cref="InvalidOperationException">This version does not know the relay.</exception>
    private static DirectoryClient RelayClient() =>
        new(Relays.AddressOf(Relays.Current) ?? throw new InvalidOperationException("This version does not know its relay. Update the mod."));

    /// <summary>
    /// Tells the player why an action failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(Exception ex) => ex switch
    {
        InvalidDataException or InvalidOperationException => ex.Message,
        DirectoryException { Status: null } => "The relay could not be reached. Check your internet connection.",
        DirectoryException directory => $"The relay refused: {directory.Message}",
        IOException or UnauthorizedAccessException => $"The mods could not be written: {ex.Message}",
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// Writes the mods as the game script reads them.
    /// </summary>
    /// <param name="listed">The mods and their states.</param>
    /// <param name="thumbnails">The cached thumbnails' paths relative to the game's folder, by their addresses.</param>
    /// <param name="descriptions">The plain lines of each fetched description, by its mod's id.</param>
    /// <returns>The lines.</returns>
    private static string ListText(Listing listed, IReadOnlyDictionary<string, string> thumbnails, IReadOnlyDictionary<string, IReadOnlyList<string>> descriptions)
    {
        var text = new StringBuilder();
        var order = new[] { ModStatus.Update, ModStatus.Changed, ModStatus.Current, ModStatus.Available };

        foreach (var mod in listed.Mods.OrderBy(mod => Array.IndexOf(order, listed.States[mod.Id].Status)).ThenBy(mod => mod.Name, StringComparer.OrdinalIgnoreCase).ThenBy(mod => mod.Id, StringComparer.Ordinal))
        {
            var state = listed.States[mod.Id];
            var thumbnail = mod.Thumbnail is { } image && thumbnails.TryGetValue(image.Url, out var path) ? path : string.Empty;
            text.AppendJoin('\t', "mod", OnOneField(mod.Id), OnOneField(mod.Name), OnOneField(mod.Author), state.Status, OnOneField(state.Installed?.Version ?? string.Empty),
                OnOneField(mod.Latest), mod.Source, OnOneField(mod.Page), mod.Install.Files.Count.ToString(CultureInfo.InvariantCulture), mod.Bytes.ToString(CultureInfo.InvariantCulture), OnOneField(mod.Summary),
                thumbnail, mod.Thumbnail?.Spoiler == true ? "1" : string.Empty).Append('\n');

            foreach (var note in mod.Notes)
            {
                text.Append("note\t").Append(OnOneField(mod.Id)).Append('\t').Append(OnOneField(note)).Append('\n');
            }

            foreach (var line in descriptions.GetValueOrDefault(mod.Id) ?? [])
            {
                text.Append("desc\t").Append(OnOneField(mod.Id)).Append('\t').Append(OnOneField(line)).Append('\n');
            }
        }

        return text.ToString();
    }

    /// <summary>
    /// Keeps a text inside its field.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text with tabs and line breaks turned into spaces.</returns>
    private static string OnOneField(string text) => text.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');

    /// <summary>
    /// The mods with how each stood in the Patch folder at one scan.
    /// </summary>
    /// <param name="Mods">The mods.</param>
    /// <param name="States">Each mod's state by its id.</param>
    private sealed record Listing(IReadOnlyList<BrowsedMod> Mods, IReadOnlyDictionary<string, ModState> States);
}
