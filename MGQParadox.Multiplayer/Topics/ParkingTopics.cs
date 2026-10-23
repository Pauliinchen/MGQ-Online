//----------------------------------------------------------------
//  ParkingTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Handed the world screen the parking session
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of turning other mods off (<see cref="ParkingSession"/>). A world is named by
/// <c>world</c> (its id), <c>mods</c> (as its creator wrote them), <c>off</c> (whether it turns other
/// mods off) and <c>name</c>. Every topic of the title screen's flow answers <see cref="State"/>.
/// </summary>
internal static class ParkingTopics
{
    /// <summary>
    /// What entering a world needs: a world and <c>claim</c> (whether to park the scripts parked for
    /// another world for this one when they are the same) in; <c>kind</c> ("none", "plan", "restart",
    /// "unlisted", "elsewhere", "unknown"), <c>plan</c>, <c>text</c> (the question or why not, nil for
    /// none), <c>also</c> (what a download offer adds), <c>claimed</c> and <c>moved</c> out.
    /// </summary>
    public const string Change = "parking.change";

    /// <summary>
    /// The scripts of the player a world turns off: <c>mods</c> and <c>off</c> in; <c>plan</c> (nil
    /// while unknown) and <c>mods</c> ([name, scripts] per mod) out.
    /// </summary>
    public const string Plan = "parking.plan";

    /// <summary>
    /// Whether this session runs with a world's other mods turned off: <c>world</c>, <c>off</c> and
    /// <c>name</c> in; <c>parked</c> and <c>text</c> (the question to the world's creator) out.
    /// </summary>
    public const string ParkedFor = "parking.parked_for";

    /// <summary>
    /// Parks the scripts and starts the game again into the world: <c>world</c>, <c>name</c> and
    /// <c>plan</c> in; <c>result</c> ("restarting", "failed", "not_parked", "held"), <c>text</c> (why
    /// not) and <c>moved</c> out.
    /// </summary>
    public const string Join = "parking.join";

    /// <summary>
    /// Starts the game again once a world's mods are installed: a world (its mods and off nil when the
    /// list lacks it) and <c>unlocked</c> in; <c>result</c> ("unlock", "restarting", "by_hand",
    /// "not_kept"), <c>text</c> and <c>moved</c> out.
    /// </summary>
    public const string RestartForMods = "parking.restart_for_mods";

    /// <summary>
    /// Starts the game again to enter a world once it is back: <c>world</c> in; <c>restarting</c> out.
    /// </summary>
    public const string Rejoin = "parking.rejoin";

    /// <summary>
    /// Takes the world the game should enter again after a restart: nothing in; its id or nil out.
    /// </summary>
    public const string TakeRejoin = "parking.take_rejoin";

    /// <summary>
    /// A title screen starts, before the world closes: nothing in.
    /// </summary>
    public const string TitleStarted = "parking.title_started";

    /// <summary>
    /// A title screen started and the world closed: <c>left_world</c> in.
    /// </summary>
    public const string TitleLeft = "parking.title_left";

    /// <summary>
    /// A world was entered: <c>world</c> (its id in the directory, nil for none) and <c>name</c> in.
    /// </summary>
    public const string Entered = "parking.entered";

    /// <summary>
    /// The start that entered a world again ended without entering it: <c>reason</c> (nil for none) in.
    /// </summary>
    public const string GiveUp = "parking.give_up";

    /// <summary>
    /// The title screen told why the game starts again: nothing in; the state and <c>restarting</c> out.
    /// </summary>
    public const string RestartNow = "parking.restart_now";

    /// <summary>
    /// The player closed the title screen's notice: nothing in.
    /// </summary>
    public const string NoticeClosed = "parking.notice_closed";

    /// <summary>
    /// Has the title screen tell something until the player closes it: <c>text</c> in.
    /// </summary>
    public const string Tell = "parking.tell";

    /// <summary>
    /// The updater started: nothing in.
    /// </summary>
    public const string UpdateStarted = "parking.update_started";

    /// <summary>
    /// The state as it stands: nothing in.
    /// </summary>
    public const string StateTopic = "parking.state";

    /// <summary>
    /// The relay's word on the open world's rule: <c>value</c> ("0" or "1"), <c>mods</c>, <c>open</c>,
    /// <c>world</c> and <c>name</c> in; <c>taken</c> and <c>kick</c> (what the player is told before
    /// leaving, nil to stay) out.
    /// </summary>
    public const string Rule = "parking.rule";

    /// <summary>
    /// Takes what a check against a fetched list found the player must be told before leaving: nothing
    /// in; the text or nil out. <see cref="WorldChanges.Parking"/> tells that one waits.
    /// </summary>
    public const string TakeKick = "parking.take_kick";


    /// <summary>
    /// Registers the topics on a context, with a session of the game folder's parking.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="services">What the topics of worlds and mods share.</param>
    /// <returns>The session, whose plan the world screen reads too.</returns>
    public static ParkingSession Register(BridgeContext context, WorldServices services)
    {
        WorldDirectory directory() => services.Directory();
        var session = new ParkingSession(
            services.Parking(),
            services.Player,
            () => PersonalKeys(directory()),
            (world, rejoin) => GameRestart.WatchParked(services.Parking(), ModFolder.Root, world, rejoin) == RestartStart.Waiting,
            () => GameRestart.AfterExit(ModFolder.Root) == RestartStart.Waiting,
            new Directory(directory));
        Register(context, session, services.Changes);
        return session;
    }

    /// <summary>
    /// Registers the topics on a context over a session.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The session.</param>
    /// <param name="changes">The changes the scripts are told of.</param>
    internal static void Register(BridgeContext context, ParkingSession session, WorldChanges changes)
    {
        context.EveryFrame(_ =>
        {
            if (session.Frame())
            {
                changes.Mark(WorldChanges.Parking);
            }
        });
        context.Register(Change, (_, request) => ChangeOf(session, request.AsHash()));
        context.Register(Plan, (_, request) => PlanOf(session, request.AsHash()));
        context.Register(ParkedFor, (_, request) =>
        {
            RubyHash world = request.AsHash();
            return new RubyHash { { "parked", session.ParkedFor(world["world"].AsText(), world["off"].AsBool()) }, { "text", ParkingTexts.OwnData(world["name"].AsText()) } };
        });
        context.Register(Join, (_, request) => JoinOf(session, request.AsHash()));
        context.Register(RestartForMods, (_, request) => RestartOf(session, request.AsHash()));
        context.Register(Rejoin, (_, request) => new RubyHash { { "restarting", session.Rejoin(request.AsHash()["world"].AsText()) } });
        context.Register(TakeRejoin, (_, _) => session.TakeRejoin());
        context.Register(TitleStarted, (_, _) => Then(session, session.TitleStarted));
        context.Register(TitleLeft, (_, request) => Then(session, () => session.TitleLeft(request.AsHash()["left_world"].AsBool())));
        context.Register(Entered, (_, request) =>
        {
            RubyHash world = request.AsHash();
            return Then(session, () => session.Entered(world["world"].IsNil ? null : world["world"].AsText(), world["name"].AsText()));
        });
        context.Register(GiveUp, (_, request) => Then(session, () => session.GiveUp(request.IsNil ? null : request.AsHash()["reason"] is { IsNil: false } reason ? reason.AsText() : null)));
        context.Register(RestartNow, (_, _) =>
        {
            bool restarting = session.RestartNow();
            RubyHash state = State(session);
            state["restarting"] = restarting;
            return state;
        });
        context.Register(NoticeClosed, (_, _) => Then(session, session.CloseNotice));
        context.Register(Tell, (_, request) => Then(session, () => session.Tell(request.AsHash()["text"].AsText())));
        context.Register(UpdateStarted, (_, _) => Then(session, session.UpdateStarted));
        context.Register(StateTopic, (_, _) => State(session));
        context.Register(Rule, (_, request) => RuleOf(session, request.AsHash()));
        context.Register(TakeKick, (_, _) => session.TakeKick());
    }

    /// <summary>
    /// Describes the state the scripts keep a copy of.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <returns><c>holding</c>, <c>due</c> (what the title screen says before it starts the game again, nil while it is not about to), <c>notice</c> (what it tells until the player closes it, nil for nothing), <c>saving_off</c>, <c>save_text</c> (what a refused save tells) and <c>moved</c> (whether scripts were moved since the last answer).</returns>
    internal static RubyHash State(ParkingSession session) => new()
    {
        { "holding", session.Holding },
        { "due", session.Due },
        { "notice", session.Notice },
        { "saving_off", session.SavingOff },
        { "save_text", ParkingTexts.SaveOff },
        { "moved", session.TakeMoved() },
    };

    /// <summary>
    /// Runs a step of the title screen's flow and answers the state after it.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="step">The step.</param>
    /// <returns>The state.</returns>
    private static RubyHash Then(ParkingSession session, Action step)
    {
        step();
        return State(session);
    }

    /// <summary>
    /// Answers <see cref="Change"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="world">The world.</param>
    /// <returns>The change.</returns>
    private static RubyHash ChangeOf(ParkingSession session, RubyHash world)
    {
        string id = world["world"].AsText();
        string name = world["name"].AsText();
        string mods = world["mods"].IsNil ? string.Empty : world["mods"].AsText();
        bool off = world["off"].AsBool();
        ParkingChange change = session.Change(id, mods, off);
        bool claimed = world["claim"] is RubyBool { Flag: true } && change.Kind == ParkingKind.None && session.Claim(id, mods, off);
        return new RubyHash
        {
            { "kind", KindName(change.Kind) },
            { "plan", Texts(change.Plan) },
            { "text", TextOf(change, name) },
            { "also", ParkingTexts.Also(change.Plan) },
            { "claimed", claimed },
            { "moved", session.TakeMoved() },
        };
    }

    /// <summary>
    /// Answers <see cref="Plan"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="world">The world.</param>
    /// <returns>The scripts it turns off and their mods.</returns>
    private static RubyHash PlanOf(ParkingSession session, RubyHash world)
    {
        IReadOnlyList<string>? plan = ParkingRules.Plan(session.Facts(), world["mods"].IsNil ? string.Empty : world["mods"].AsText(), world["off"].AsBool());
        return new RubyHash
        {
            { "plan", plan == null ? RubyNil.Value : Texts(plan) },
            { "mods", new RubyArray(ParkingRules.ModsOf(plan ?? []).Select(mod => (RubyValue)new RubyArray([mod.Name, mod.Scripts]))) },
        };
    }

    /// <summary>
    /// Answers <see cref="Join"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="request">The world and the plan.</param>
    /// <returns>How it went.</returns>
    private static RubyHash JoinOf(ParkingSession session, RubyHash request)
    {
        List<string> plan = request["plan"].AsArray().Select(path => path.AsText()).ToList();
        string name = request["name"].AsText();
        JoinResult result = session.Join(request["world"].AsText(), plan);
        string? text = result switch
        {
            JoinResult.Held => ParkingTexts.Held,
            JoinResult.NotParked => plan.Count == 0 ? ParkingTexts.NotBack : ParkingTexts.ParkFailed(name),
            JoinResult.Failed => ParkingTexts.RestartFailed(name),
            _ => null,
        };
        string resultName = result switch
        {
            JoinResult.Restarting => "restarting",
            JoinResult.Held => "held",
            JoinResult.NotParked => "not_parked",
            _ => "failed",
        };
        return new RubyHash { { "result", resultName }, { "text", text }, { "moved", session.TakeMoved() } };
    }

    /// <summary>
    /// Answers <see cref="RestartForMods"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="request">The world and whether its lock is open.</param>
    /// <returns>How it went.</returns>
    private static RubyHash RestartOf(ParkingSession session, RubyHash request)
    {
        string name = request["name"].AsText();
        (bool, string)? rule = request["off"].IsNil ? null : (request["off"].AsBool(), request["mods"].IsNil ? string.Empty : request["mods"].AsText());
        var (result, change) = session.RestartForMods(request["world"].AsText(), rule, request["unlocked"].AsBool());
        (string resultName, string? text) = result switch
        {
            ModsRestart.Unlock => ("unlock", null),
            ModsRestart.Restarting => ("restarting", null),
            ModsRestart.ByHand => ("by_hand", ParkingTexts.StartByHand(name)),
            _ => ("not_kept", change?.Kind == ParkingKind.Elsewhere ? ParkingTexts.Elsewhere(change.Stuck)
                : change is { Kind: ParkingKind.Plan, Plan.Count: 0 } ? ParkingTexts.NotBackOn(name) : ParkingTexts.NotKept(name)),
        };
        return new RubyHash { { "result", resultName }, { "text", text }, { "moved", session.TakeMoved() } };
    }

    /// <summary>
    /// Answers <see cref="Rule"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="request">The relay's word and the open world.</param>
    /// <returns>Whether it was taken and what the player is told.</returns>
    private static RubyHash RuleOf(ParkingSession session, RubyHash request)
    {
        var (taken, kick) = session.Rule(request["value"].AsText(), request["mods"].IsNil ? string.Empty : request["mods"].AsText(), request["open"].AsBool(),
            request["world"].IsNil ? null : request["world"].AsText(), request["name"].IsNil ? string.Empty : request["name"].AsText());
        return new RubyHash { { "taken", taken }, { "kick", kick } };
    }

    /// <summary>
    /// Tells what the player is told for a change, as the world screen says it.
    /// </summary>
    /// <param name="change">The change.</param>
    /// <param name="name">The world's name.</param>
    /// <returns>The question or why the world is not entered; <see langword="null"/> when nothing changes.</returns>
    private static string? TextOf(ParkingChange change, string name) => change.Kind switch
    {
        ParkingKind.Plan => ParkingTexts.Confirm(name, change.Plan),
        ParkingKind.Unknown => ParkingTexts.Catalog,
        ParkingKind.Unlisted => ParkingTexts.Unlisted(name),
        ParkingKind.Elsewhere => ParkingTexts.Elsewhere(change.Stuck),
        ParkingKind.Restart => ParkingTexts.RestartFirst(name),
        _ => null,
    };

    /// <summary>
    /// Names a kind of change as the scripts read it.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <returns>Its name, such as "plan".</returns>
    private static string KindName(ParkingKind kind) => kind switch
    {
        ParkingKind.Plan => "plan",
        ParkingKind.Restart => "restart",
        ParkingKind.Unlisted => "unlisted",
        ParkingKind.Elsewhere => "elsewhere",
        ParkingKind.Unknown => "unknown",
        _ => "none",
    };

    /// <summary>
    /// Lists the keys of the catalog's personal mods and of their names.
    /// </summary>
    /// <param name="directory">The world directory, which fetched the catalog.</param>
    /// <returns>The keys, <see langword="null"/> while the catalog is unknown.</returns>
    private static IReadOnlyCollection<string>? PersonalKeys(WorldDirectory directory) =>
        directory.CatalogNow().Catalog is { } catalog
            ? ModTopics.PersonalKeys(catalog).ToHashSet(StringComparer.Ordinal)
            : null;

    /// <summary>
    /// Writes texts as an Array.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The Array.</returns>
    private static RubyArray Texts(IEnumerable<string> texts) => new(texts.Select(text => (RubyValue)text));

    /// <summary>
    /// The world directory as the parked mods read it.
    /// </summary>
    /// <param name="directory">Gives the world directory.</param>
    private sealed class Directory(Func<WorldDirectory> directory) : IParkingDirectory
    {
        /// <inheritdoc />
        public bool Listing => directory().ListedNow(string.Empty).State == "loading";

        /// <inheritdoc />
        public void Refresh() => directory().Refresh();

        /// <inheritdoc />
        public (bool OtherModsOff, string Mods)? RuleOf(string world) =>
            directory().ListedNow(world) is ("ready", { ModsUnread: false } listed) ? (listed.OtherModsOff, listed.About.Mods) : null;
    }
}
