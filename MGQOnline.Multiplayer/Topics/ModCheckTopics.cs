//----------------------------------------------------------------
//  ModCheckTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Checked a world's required mods by the Mod Framework's list and the creator's versions and hashes
//                            - Took the personal mods and the files the battle server downloads from the website's catalog
//                            - Sent an admin's Mod Config options of each website mod's version to the website
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Left out an option whose default has a type no world keeps
//                            - Took a mod's Mod Config options as values
//      Paulinchen  2026-10-31: Read Patch anew for the creator's hashes, so a mod put there right before counts
//      Paulinchen  2026-10-30: Told the mods a world's session loads and those it turns off now
//                            - Left installing a world's mods to the Mod Framework
//      Paulinchen  2026-10-23: Handed the world screen the check
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts check a world's required mods against the mods the
/// Mod Framework lists and the creator's copies (<see cref="ModCheck"/>), tell the mods a world's
/// session loads (<see cref="SessionMods"/>), send an admin's Mod Config options to the website and
/// list the mods the battle server runs.
/// </summary>
internal sealed class ModCheckTopics
{
    /// <summary>
    /// Checks a world's required mods: <c>mods</c>, <c>versions</c> and <c>hashes</c> (the creator's)
    /// as the world writes them, and <c>world</c>, its name, to log the check, in; <c>known</c>
    /// (whether the Mod Framework told the installed mods), <c>catalog</c> (whether the website's
    /// catalog, which tells the personal mods, is) and <c>rows</c> (each differing mod's <c>name</c>,
    /// <c>yours</c>, <c>worlds</c> and <c>text</c>) out.
    /// </summary>
    public const string CheckTopic = "mods.check";

    /// <summary>
    /// Writes the creator's copies of a world's required mods, reading Patch anew, see
    /// <see cref="ModCheck.CreatorPins"/>: the mods as written in; <c>versions</c> and <c>hashes</c> out.
    /// </summary>
    public const string CreatorPinsTopic = "mods.creator_pins";

    /// <summary>
    /// Forgets the scripts in Patch and their hashes, as the world screen opens or after an install:
    /// nothing in; nothing out.
    /// </summary>
    public const string ForgetTopic = "mods.forget";

    /// <summary>
    /// Takes the installed mods as the Mod Framework lists them (<c>Mods.state</c>): <c>mods</c>, each
    /// [name, title, version, id (<c>site:</c> and its slug, nil for a mod the website does not have),
    /// on], in, or nil without the framework; nothing out.
    /// </summary>
    public const string FrameworkTopic = "mods.framework";

    /// <summary>
    /// Lists the mods of a world the battle server runs, see <see cref="ModCheck.Served"/>: the world's
    /// mods in; [key, kind, version, [[path, hash], ...]] each out.
    /// </summary>
    public const string ServedTopic = "mods.served";

    /// <summary>
    /// Names the website mods whose Mod Config options an admin's game sends now, once a session per
    /// mod's version: nothing in; [slug, name in Patch, version] each out, which counts as sent.
    /// </summary>
    public const string ReportTopic = "mods.report";

    /// <summary>
    /// Sends a website mod's Mod Config options: <c>key</c> (its slug), <c>version</c> and
    /// <c>options</c> (each as <see cref="ModOption.Of"/> takes it) in; true when sent.
    /// </summary>
    public const string OptionsTopic = "mods.options";

    /// <summary>
    /// Tells the mods a game session in a world that turns other mods off loads, see
    /// <see cref="SessionMods.Of"/>: <c>world</c> (its name), <c>mods</c> (the world's, as written),
    /// <c>names</c> (the player's mods as the Mod Framework names them) and <c>stays_on</c> (those that
    /// run from the start of the game) in; <c>only</c>, <c>off</c> and <c>text</c> (what the player is
    /// told, see <see cref="SessionMods.Entered"/>) out, nil while the website's catalog is unknown and
    /// a mod the world does not name might be personal.
    /// </summary>
    public const string SessionTopic = "mods.session";

    /// <summary>
    /// Tells the mods of a session that its world turns off now that its rule or mods changed, see
    /// <see cref="SessionMods.NowTurnedOff"/>: <c>world</c> (its name), <c>off</c> (whether the world
    /// turns other mods off now), <c>mods</c> and <c>running</c> (the mods the session loaded but those
    /// that run from the start) in; <c>off</c> (the names, none while the website's catalog is unknown)
    /// and <c>text</c> (what the player is told, nil for none) out.
    /// </summary>
    public const string NowOffTopic = "mods.now_off";

    /// <summary>
    /// What starts the id of a mod the website has, as the Mod Framework names it.
    /// </summary>
    private const string SitePrefix = "site:";

    /// <summary>
    /// Reads the website's catalog as last fetched, <see langword="null"/> before the first.
    /// </summary>
    private readonly Func<SiteCatalog?> _catalog;

    /// <summary>
    /// Lists the scripts in Patch, <see langword="null"/> when a folder could not be read.
    /// </summary>
    private readonly Func<IReadOnlyList<string>?> _installed;

    /// <summary>
    /// Hashes a file relative to the game folder, <see langword="null"/> when it is missing or cannot be read.
    /// </summary>
    private readonly Func<string, string?> _hash;

    /// <summary>
    /// Sends a mod's options by its slug and version; false without a player.
    /// </summary>
    private readonly Func<string, string, IReadOnlyList<ModOption>, bool> _sendOptions;

    /// <summary>
    /// The files' hashes read since the scripts in Patch were last forgotten, a missing file's <see langword="null"/>.
    /// </summary>
    private readonly Dictionary<string, string?> _hashes = new(StringComparer.Ordinal);

    /// <summary>
    /// The version of each website mod whose options this session sent, by its slug.
    /// </summary>
    private readonly Dictionary<string, string> _reported = new(StringComparer.Ordinal);

    /// <summary>
    /// Where the lines go.
    /// </summary>
    private readonly IBridgeLog _log;

    /// <summary>
    /// The installed mods as the Mod Framework last listed them, <see langword="null"/> before it did.
    /// </summary>
    private IReadOnlyList<InstalledMod>? _mods;

    /// <summary>
    /// The check as the Mod Framework's list and Patch stand, <see langword="null"/> until it is asked for.
    /// </summary>
    private ModCheck? _check;

    /// <summary>
    /// The scripts in Patch since they were last forgotten, <see langword="null"/> before they are read again.
    /// </summary>
    private IReadOnlyList<(string Key, string Path)>? _scripts;

    /// <summary>
    /// Whether <see cref="_scripts"/> was read since the scripts were last forgotten.
    /// </summary>
    private bool _scriptsRead;

    /// <summary>
    /// Creates the topics.
    /// </summary>
    /// <param name="catalog">Reads the website's catalog as last fetched.</param>
    /// <param name="installed">Lists the scripts in Patch.</param>
    /// <param name="hash">Hashes a file relative to the game folder.</param>
    /// <param name="sendOptions">Sends a mod's options by its slug and version.</param>
    /// <param name="log">Where the lines go.</param>
    public ModCheckTopics(Func<SiteCatalog?> catalog, Func<IReadOnlyList<string>?> installed, Func<string, string?> hash, Func<string, string, IReadOnlyList<ModOption>, bool> sendOptions, IBridgeLog log)
    {
        _catalog = catalog;
        _installed = installed;
        _hash = hash;
        _sendOptions = sendOptions;
        _log = log;
    }

    /// <summary>
    /// Registers the topics of the game's own directory on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="services">What the topics of worlds and mods share.</param>
    /// <returns>The topics, whose check the world screen reads too.</returns>
    public static ModCheckTopics Register(BridgeContext context, WorldServices services)
    {
        ModCheckTopics topics = new(
            () => services.Directory().CatalogNow().Catalog,
            services.Scripts,
            HashOf,
            (slug, version, options) => services.Directory().SendModOptions(slug, version, options),
            context.Log);
        topics.Register(context, services.Changes);
        return topics;
    }

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="changes">Tells the screen once the website's catalog or the installed mods changed.</param>
    public void Register(BridgeContext context, WorldChanges changes)
    {
        long revision = 0;
        SiteCatalog? seen = _catalog();
        changes.Watch(() =>
        {
            SiteCatalog? now = _catalog();
            if (!ReferenceEquals(now, seen))
            {
                seen = now;
                revision++;
            }

            return revision;
        }, WorldChanges.Mods);
        context.Register(CheckTopic, (_, request) => CheckOf(request.AsHash()));
        context.Register(CreatorPinsTopic, (_, request) =>
        {
            Forget();
            ModPins pins = Check().CreatorPins(Text(request), _log.Write);
            return new RubyHash { { "versions", pins.Versions }, { "hashes", pins.Hashes } };
        });
        context.Register(ForgetTopic, (_, _) =>
        {
            Forget();
            changes.Mark(WorldChanges.Mods);
            return null;
        });
        context.Register(FrameworkTopic, (_, request) =>
        {
            TakeFramework(request);
            changes.Mark(WorldChanges.Mods);
            return null;
        });
        context.Register(ServedTopic, (_, request) => new RubyArray(Served(Text(request)).Select(ServedValue)));
        context.Register(SessionTopic, (_, request) => SessionOf(request.AsHash()));
        context.Register(NowOffTopic, (_, request) => NowOffOf(request.AsHash()));
        context.Register(ReportTopic, (_, _) => Report());
        context.Register(OptionsTopic, (_, request) => SendOptions(request.AsHash()));
    }

    /// <summary>
    /// Forgets the scripts in Patch and their hashes, so the next check reads them anew.
    /// </summary>
    public void Forget()
    {
        _hashes.Clear();
        _scripts = null;
        _scriptsRead = false;
        _check = null;
    }

    /// <summary>
    /// Lists the mods of a world the battle server runs.
    /// </summary>
    /// <param name="mods">The world's mods as written.</param>
    /// <returns>The mods, see <see cref="ModCheck.Served"/>.</returns>
    public IReadOnlyList<ServedMod> Served(string? mods)
    {
        SiteCatalog? catalog = _catalog();
        return Check().Served(mods, Personal() ?? [], (slug, version) => catalog?.FilesOf(slug, version));
    }

    /// <summary>
    /// Gets the check as the Mod Framework's list and Patch stand, reading Patch once until it is forgotten.
    /// </summary>
    /// <returns>The check.</returns>
    public ModCheck Check()
    {
        if (_check != null)
        {
            return _check;
        }

        if (!_scriptsRead)
        {
            _scripts = _installed()?.Select(path => (ModKey.Of(Path.GetFileName(path)), path)).ToList();
            _scriptsRead = true;
        }

        _check = new ModCheck(_mods, _scripts, CachedHash);
        return _check;
    }

    /// <summary>
    /// Lists the keys the world's mods name the personal mods by.
    /// </summary>
    /// <returns>The keys, <see langword="null"/> while the website's catalog is unknown.</returns>
    public IReadOnlyCollection<string>? Personal() => _catalog()?.PersonalKeys(_mods);

    /// <summary>
    /// Hashes a mod's file as the creator's hashes are made, see <see cref="ModHash"/>.
    /// </summary>
    /// <param name="path">The file, relative to the game folder.</param>
    /// <returns>The hash, <see langword="null"/> when the file is missing or cannot be read.</returns>
    internal static string? HashOf(string path)
    {
        try
        {
            string file = ModFolder.GamePathOf(path);
            return File.Exists(file) ? ModHash.OfFile(file) : null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        {
            Log.Write($"hashing {path} failed: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Takes the installed mods as the Mod Framework lists them.
    /// </summary>
    /// <param name="request"><c>mods</c>, each [name, title, version, id, on]; nil without the framework.</param>
    private void TakeFramework(RubyValue request)
    {
        _check = null;
        if (request.IsNil)
        {
            _mods = null;
            _log.Write("the Mod Framework lists no installed mods, so the creator's versions are not compared");
            return;
        }

        _mods = [.. request.AsHash()["mods"].AsArray().Select(item => item.AsArray()).Select(mod => new InstalledMod(
            mod[0].AsText(),
            mod[1].IsNil ? mod[0].AsText() : mod[1].AsText(),
            mod[2].IsNil ? string.Empty : mod[2].AsText(),
            mod[3].IsNil || !mod[3].AsText().StartsWith(SitePrefix, StringComparison.Ordinal) ? null : mod[3].AsText()[SitePrefix.Length..],
            mod[4].AsBool()))];
        _log.Write($"the Mod Framework lists {_mods.Count} installed mod(s): {string.Join(", ", _mods.Select(mod => $"{mod.Name} {(mod.Version.Length > 0 ? mod.Version : "?")}{(mod.Slug != null ? $" (website {mod.Slug})" : string.Empty)}{(mod.On ? string.Empty : ", off")}"))}");
    }

    /// <summary>
    /// Hashes a file once until the scripts are forgotten.
    /// </summary>
    /// <param name="path">The file, relative to the game folder.</param>
    /// <returns>The hash, <see langword="null"/> when the file is missing or cannot be read.</returns>
    private string? CachedHash(string path)
    {
        if (!_hashes.TryGetValue(path, out string? hash))
        {
            hash = _hash(path);
            _hashes[path] = hash;
        }

        return hash;
    }

    /// <summary>
    /// Answers <see cref="CheckTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    private RubyHash CheckOf(RubyHash request)
    {
        ModCheck check = Check();
        string mods = Text(request["mods"]);
        string versions = Text(request["versions"]);
        string hashes = Text(request["hashes"]);
        IReadOnlyList<ModCheckRow> rows = check.Differing(mods, versions, hashes);
        if (!request["world"].IsNil)
        {
            _log.Write(check.CheckLine(request["world"].AsText(), mods, versions, hashes, rows));
        }

        return new RubyHash
        {
            { "known", check.Known },
            { "catalog", _catalog() != null },
            { "rows", new RubyArray(rows.Select(RowValue)) },
        };
    }

    /// <summary>
    /// Answers <see cref="SessionTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The answer, nil while the website's catalog is unknown.</returns>
    private RubyValue? SessionOf(RubyHash request)
    {
        SessionPlan? plan = SessionMods.Of(TextsOf(request["names"]), Text(request["mods"]), Personal());
        if (plan == null)
        {
            _log.Write("the mods of a world's session are unknown until the website's mod catalog loads");
            return null;
        }

        string text = SessionMods.Entered(Text(request["world"]), plan.Off, TextsOf(request["stays_on"]));
        return new RubyHash { { "only", ModTopics.Texts(plan.Only) }, { "off", ModTopics.Texts(plan.Off) }, { "text", text.Length == 0 ? null : text } };
    }

    /// <summary>
    /// Answers <see cref="NowOffTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    private RubyHash NowOffOf(RubyHash request)
    {
        IReadOnlyList<string> off = SessionMods.NowTurnedOff(request["off"].AsBool(), TextsOf(request["running"]), Text(request["mods"]), Personal());
        return new RubyHash { { "off", ModTopics.Texts(off) }, { "text", off.Count == 0 ? null : SessionMods.NowOff(Text(request["world"])) } };
    }

    /// <summary>
    /// Reads an Array of texts.
    /// </summary>
    /// <param name="value">The Array, nil for none.</param>
    /// <returns>The texts.</returns>
    private static IReadOnlyList<string> TextsOf(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(item => item.AsText())];

    /// <summary>
    /// Answers <see cref="ReportTopic"/>.
    /// </summary>
    /// <returns>The mods to send the options of now.</returns>
    private RubyArray Report()
    {
        RubyArray report = [];
        foreach (InstalledMod mod in _mods ?? [])
        {
            if (!mod.KnownVersion || (_reported.TryGetValue(mod.Slug!, out string? sent) && sent == mod.Version))
            {
                continue;
            }

            _reported[mod.Slug!] = mod.Version;
            report.Add(new RubyArray([mod.Slug!, mod.Name, mod.Version]));
        }

        return report;
    }

    /// <summary>
    /// Answers <see cref="OptionsTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>Whether the options were sent.</returns>
    private RubyValue SendOptions(RubyHash request)
    {
        IReadOnlyList<ModOption> options = [.. request["options"].AsArray().Select(option => ModOption.Of(option.AsHash())).OfType<ModOption>()];
        string slug = request["key"].AsText();
        string version = request["version"].AsText();
        _log.Write($"sending {options.Count} Mod Config option(s) of {slug} {version} to the website");
        return _sendOptions(slug, version, options);
    }

    /// <summary>
    /// Describes a row of the check for the game script.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>Its name, this game's copy, the world's version and the text.</returns>
    private static RubyValue RowValue(ModCheckRow row) => new RubyHash
    {
        { "name", row.Name },
        { "yours", row.Yours },
        { "worlds", row.Worlds },
        { "text", row.Text },
    };

    /// <summary>
    /// Describes a mod the battle server runs for the game script.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>[key, kind, version, [[path, hash], ...]].</returns>
    private static RubyValue ServedValue(ServedMod mod) =>
        new RubyArray([mod.Key, mod.Kind, mod.Version, new RubyArray(mod.Files.Select(file => (RubyValue)new RubyArray([file.Key, file.Value])))]);

    /// <summary>
    /// Reads a text, nil as empty.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Text(RubyValue value) => value.IsNil ? "" : value.AsText();
}
