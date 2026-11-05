//----------------------------------------------------------------
//  ModCheckTopics.cs
//
//  Changelog:
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
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts check a world's required mods against the relay's
/// catalog and this game's copies (<see cref="ModCheck"/>), tell the mods a world's session loads
/// (<see cref="SessionMods"/>), send an admin's Mod Config options and list the mods the battle server runs.
/// </summary>
internal sealed class ModCheckTopics
{
    /// <summary>
    /// Checks a world's required mods: <c>mods</c> and <c>hashes</c> (the creator's) as the world
    /// writes them, and <c>world</c>, its name, to log the check, in; <c>known</c> (whether the catalog
    /// is), <c>rows</c> (each differing mod's <c>name</c>, <c>yours</c>, <c>worlds</c>, <c>key</c> of
    /// the catalog mod to download, <c>target</c>, <c>text</c> and <c>downloadable</c>) and
    /// <c>summary</c> (for the world screen, nil when none differs) out.
    /// </summary>
    public const string CheckTopic = "mods.check";

    /// <summary>
    /// Writes the creator's hashes of the required mods outside the catalog, reading Patch anew: the
    /// mods as written in; the "name=hash" pairs out.
    /// </summary>
    public const string CreatorHashesTopic = "mods.creator_hashes";

    /// <summary>
    /// Forgets the scripts in Patch and their hashes, as the world screen opens or after an install or
    /// a park: nothing in; nothing out.
    /// </summary>
    public const string ForgetTopic = "mods.forget";

    /// <summary>
    /// Lists the mods of a world the battle server runs, see <see cref="ModCheck.Served"/>: the world's
    /// mods in; [key, kind, version, [[path, hash], ...]] each out.
    /// </summary>
    public const string ServedTopic = "mods.served";

    /// <summary>
    /// Names the catalog mods whose Mod Config options an admin's game sends now, once a session per
    /// mod's current version: nothing in; [key, name, version this copy is ("" for none the catalog
    /// knows)] each out, which counts as sent.
    /// </summary>
    public const string ReportTopic = "mods.report";

    /// <summary>
    /// Sends a mod's Mod Config options: <c>key</c>, <c>version</c> and <c>options</c> (each as
    /// <see cref="ModOption.Of"/> takes it) in; true when sent.
    /// </summary>
    public const string OptionsTopic = "mods.options";

    /// <summary>
    /// Tells the mods a game session in a world that turns other mods off loads, see
    /// <see cref="SessionMods.Of"/>: <c>world</c> (its name), <c>mods</c> (the world's, as written),
    /// <c>names</c> (the player's mods as the Mod Framework names them) and <c>stays_on</c> (those that
    /// run from the start of the game) in; <c>only</c>, <c>off</c> and <c>text</c> (what the player is
    /// told, see <see cref="SessionMods.Entered"/>) out, nil while the catalog is unknown and a mod
    /// the world does not name might be personal.
    /// </summary>
    public const string SessionTopic = "mods.session";

    /// <summary>
    /// Tells the mods of a session that its world turns off now that its rule or mods changed, see
    /// <see cref="SessionMods.NowTurnedOff"/>: <c>world</c> (its name), <c>off</c> (whether the world
    /// turns other mods off now), <c>mods</c> and <c>running</c> (the mods the session loaded but those
    /// that run from the start) in; <c>off</c> (the names, none while the catalog is unknown) and
    /// <c>text</c> (what the player is told, nil for none) out.
    /// </summary>
    public const string NowOffTopic = "mods.now_off";

    /// <summary>
    /// Reads the catalog as last fetched, <see langword="null"/> before the first.
    /// </summary>
    private readonly Func<ModCatalog?> _catalog;

    /// <summary>
    /// Lists the scripts in Patch, <see langword="null"/> when a folder could not be read.
    /// </summary>
    private readonly Func<IReadOnlyList<string>?> _installed;

    /// <summary>
    /// Hashes a file relative to the game folder, <see langword="null"/> when it is missing or cannot be read.
    /// </summary>
    private readonly Func<string, string?> _hash;

    /// <summary>
    /// Sends a mod's options; false without a player.
    /// </summary>
    private readonly Func<string, string, IReadOnlyList<ModOption>, bool> _sendOptions;

    /// <summary>
    /// The files' hashes read since the scripts in Patch were last forgotten, a missing file's <see langword="null"/>.
    /// </summary>
    private readonly Dictionary<string, string?> _hashes = new(StringComparer.Ordinal);

    /// <summary>
    /// The current version of each mod whose options this session sent, by the mod's key.
    /// </summary>
    private readonly Dictionary<string, string> _reported = new(StringComparer.Ordinal);

    /// <summary>
    /// Where the lines go.
    /// </summary>
    private readonly IBridgeLog _log;

    /// <summary>
    /// The catalog the check was made with.
    /// </summary>
    private ModCatalog? _checkedCatalog;

    /// <summary>
    /// The check as the catalog and Patch stand, <see langword="null"/> until it is asked for.
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
    /// <param name="catalog">Reads the catalog as last fetched.</param>
    /// <param name="installed">Lists the scripts in Patch.</param>
    /// <param name="hash">Hashes a file relative to the game folder.</param>
    /// <param name="sendOptions">Sends a mod's options.</param>
    /// <param name="log">Where the lines go.</param>
    public ModCheckTopics(Func<ModCatalog?> catalog, Func<IReadOnlyList<string>?> installed, Func<string, string?> hash, Func<string, string, IReadOnlyList<ModOption>, bool> sendOptions, IBridgeLog log)
    {
        _catalog = catalog;
        _installed = installed;
        _hash = hash;
        _sendOptions = sendOptions;
        _log = log;
    }

    /// <summary>
    /// Registers the topics of the game's own directory and parking on a context.
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
            (key, version, options) => services.Directory().SendModOptions(key, version, options),
            context.Log);
        topics.Register(context, services.Changes);
        return topics;
    }

    /// <summary>
    /// Registers the topics on a context and marks <see cref="WorldChanges.Mods"/> whenever the catalog changes.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="changes">The changes the scripts are told of.</param>
    public void Register(BridgeContext context, WorldChanges changes)
    {
        long revision = 0;
        ModCatalog? seen = _catalog();
        changes.Watch(() =>
        {
            ModCatalog? now = _catalog();
            if (!ReferenceEquals(now, seen))
            {
                seen = now;
                revision++;
            }

            return revision;
        }, WorldChanges.Mods);

        context.Register(CheckTopic, (_, request) => CheckOf(request.AsHash()));
        context.Register(CreatorHashesTopic, (_, request) =>
        {
            Forget();
            return Check().CreatorHashes(Text(request), _log.Write);
        });
        context.Register(ForgetTopic, (_, _) =>
        {
            Forget();
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
    /// Forgets the scripts in Patch and their hashes.
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
    /// <returns>The mods.</returns>
    public IReadOnlyList<ServedMod> Served(string? mods)
    {
        ModCatalog? catalog = _catalog();
        IReadOnlyCollection<string> personal = catalog == null ? [] : ModTopics.Readable(catalog).Personal;
        return Check().Served(mods, personal);
    }

    /// <summary>
    /// Makes the check as the catalog and Patch stand, made anew once the catalog changed.
    /// </summary>
    /// <returns>The check.</returns>
    public ModCheck Check()
    {
        ModCatalog? catalog = _catalog();
        if (_check != null && ReferenceEquals(catalog, _checkedCatalog))
        {
            return _check;
        }

        if (!_scriptsRead)
        {
            _scripts = _installed()?.Select(path => (ModKey.Of(Path.GetFileName(path)), path)).ToList();
            _scriptsRead = true;
        }

        _checkedCatalog = catalog;
        _check = new ModCheck(catalog == null ? null : ModTopics.Readable(catalog).Mods, _scripts, CachedHash);
        return _check;
    }

    /// <summary>
    /// Hashes an installed file the way the catalog does.
    /// </summary>
    /// <param name="path">The file, relative to the game folder, with forward slashes.</param>
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
    /// Hashes a file once until the scripts are forgotten.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>Its hash.</returns>
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
    /// <param name="request">The world's mods, hashes and name.</param>
    /// <returns>The check.</returns>
    private RubyHash CheckOf(RubyHash request)
    {
        ModCheck check = Check();
        string mods = Text(request["mods"]);
        string hashes = Text(request["hashes"]);
        IReadOnlyList<ModCheckRow> rows = check.Differing(mods, hashes);
        if (!request["world"].IsNil)
        {
            _log.Write(check.CheckLine(request["world"].AsText(), mods, hashes, rows));
        }

        return new RubyHash
        {
            { "known", check.CatalogKnown },
            { "rows", new RubyArray(rows.Select(RowValue)) },
            { "summary", rows.Count == 0 ? null : ModCheck.Summary(request["world"].IsNil ? "" : request["world"].AsText(), rows) },
        };
    }

    /// <summary>
    /// Answers <see cref="SessionTopic"/>.
    /// </summary>
    /// <param name="request">The world's mods and the player's.</param>
    /// <returns>The session's mods and those it leaves out; nil while unknown.</returns>
    private RubyValue? SessionOf(RubyHash request)
    {
        SessionPlan? plan = SessionMods.Of(TextsOf(request["names"]), Text(request["mods"]), Personal());
        if (plan == null)
        {
            _log.Write("the mods of a world's session are unknown until the catalog loads");
            return null;
        }

        string text = SessionMods.Entered(Text(request["world"]), plan.Off, TextsOf(request["stays_on"]));
        return new RubyHash { { "only", ModTopics.Texts(plan.Only) }, { "off", ModTopics.Texts(plan.Off) }, { "text", text.Length == 0 ? null : text } };
    }

    /// <summary>
    /// Answers <see cref="NowOffTopic"/>.
    /// </summary>
    /// <param name="request">The world's name, its rule and mods, and the mods the session runs.</param>
    /// <returns>The mods it turns off now and what the player is told.</returns>
    private RubyHash NowOffOf(RubyHash request)
    {
        IReadOnlyList<string> off = SessionMods.NowTurnedOff(request["off"].AsBool(), TextsOf(request["running"]), Text(request["mods"]), Personal());
        return new RubyHash { { "off", ModTopics.Texts(off) }, { "text", off.Count == 0 ? null : SessionMods.NowOff(Text(request["world"])) } };
    }

    /// <summary>
    /// Lists the keys of the catalog's personal mods.
    /// </summary>
    /// <returns>The keys; <see langword="null"/> while the catalog is unknown.</returns>
    private IReadOnlyCollection<string>? Personal() => _catalog() is { } catalog ? ModTopics.Readable(catalog).Personal : null;

    /// <summary>
    /// Reads a list of texts that may be nil.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The texts, none for nil.</returns>
    private static IReadOnlyList<string> TextsOf(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(item => item.AsText())];

    /// <summary>
    /// Answers <see cref="ReportTopic"/>.
    /// </summary>
    /// <returns>The mods to report.</returns>
    private RubyArray Report()
    {
        ModCheck check = Check();
        RubyArray report = [];
        foreach (CheckedMod mod in _catalog() is { } catalog ? ModTopics.Readable(catalog).Mods : [])
        {
            string? version = check.InstalledVersion(mod);
            if (version == null || mod.OptionsVersion == mod.Version || (_reported.TryGetValue(mod.Key, out string? sent) && sent == mod.Version))
            {
                continue;
            }

            if (version.Length > 0 && mod.OptionsVersion == version)
            {
                continue;
            }

            _reported[mod.Key] = mod.Version;
            report.Add(new RubyArray([mod.Key, mod.Name, version]));
        }

        return report;
    }

    /// <summary>
    /// Answers <see cref="OptionsTopic"/>.
    /// </summary>
    /// <param name="request">The mod's key, the version and the options.</param>
    /// <returns>Whether they were sent.</returns>
    private RubyValue SendOptions(RubyHash request)
    {
        IReadOnlyList<ModOption> options = [.. request["options"].AsArray().Select(option => ModOption.Of(option.AsHash())).OfType<ModOption>()];
        string key = request["key"].AsText();
        string version = request["version"].AsText();
        _log.Write($"sending {options.Count} Mod Config option(s) of {key} {(version.Length == 0 ? "of no known version" : version)}");
        return _sendOptions(key, version, options);
    }

    /// <summary>
    /// Writes a row for the scripts.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The row as a Hash.</returns>
    private static RubyValue RowValue(ModCheckRow row) => new RubyHash
    {
        { "name", row.Name },
        { "yours", row.Yours },
        { "worlds", row.Worlds },
        { "key", row.Key },
        { "target", row.Target },
        { "text", row.Text },
        { "downloadable", row.Downloadable },
    };

    /// <summary>
    /// Writes a mod the battle server runs for the scripts.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>[key, kind, version, [[path, hash], ...]].</returns>
    private static RubyValue ServedValue(ServedMod mod) =>
        new RubyArray([mod.Key, mod.Kind, mod.Version, new RubyArray(mod.Files.Select(file => (RubyValue)new RubyArray([file.Key, file.Value])))]);

    /// <summary>
    /// Reads a text that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, empty for nil.</returns>
    private static string Text(RubyValue value) => value.IsNil ? "" : value.AsText();
}
