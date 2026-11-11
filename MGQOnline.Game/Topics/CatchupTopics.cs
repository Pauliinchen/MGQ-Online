//----------------------------------------------------------------
//  CatchupTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Handed the player's level after each look to the story track the relay's gates read
//      Paulinchen  2026-11-08: Told the scripts which classes of story keys are shared in a story
//      Paulinchen  2026-11-05: Answered a Classic member's catch-up by the engine in its Classic settings
//                            - Registered the topics of how a Classic member plays the leader's story: whether both play one story, who follows it, how the member keeps it and what their own story is once they leave
//                            - Registered the topic of the side a player takes along in either world type
//                            - Registered the topic of the Classic key item loan
//                            - Dropped the topic of the items a Classic party found, which the story replay hands over
//                            - Registered the topic of a Classic member's catch-up by the frozen rows
//                            - Registered the topic of the Medal King's gift in a Classic world
//      Paulinchen  2026-11-01: Registered the topic of the items a Classic party found
//                            - Registered the topic of which companions of the Alice and Ilias choice may join a player
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the catch-up (world_catchup.rbx and coop_story.rbx), decided by
/// <see cref="CatchupEngine"/> over the catch-up's tables of the story mapping the DLL holds, one
/// engine and a Raid World's save's notes per context.
/// </summary>
public static class CatchupTopics
{
    /// <summary>
    /// Lists what the snapshot reads, see <see cref="CatchupEngine.Keys"/>: nothing in; nil before
    /// the story mapping came.
    /// </summary>
    public const string KeysTopic = "catchup.keys";

    /// <summary>
    /// One look at the player's story, see <see cref="CatchupEngine.Check"/>.
    /// </summary>
    public const string CheckTopic = "catchup.check";

    /// <summary>
    /// A note of the world's story for the save's notes, see <see cref="CatchupEngine.Note"/>.
    /// </summary>
    public const string NoteTopic = "catchup.note";

    /// <summary>
    /// Whether a companion the player's own event hands out waits for the join's gate, see
    /// <see cref="CatchupEngine.HoldJoin"/>.
    /// </summary>
    public const string HoldTopic = "catchup.hold_join";

    /// <summary>
    /// What the catch-up hands out by level, see <see cref="CatchupEngine.Unlocks"/>.
    /// </summary>
    public const string UnlocksTopic = "catchup.unlocks";

    /// <summary>
    /// Which companions of the Alice and Ilias choice may join a player, in either world type, see
    /// <see cref="CompanionScope.Answer"/>: every companion while the story mapping has not come.
    /// </summary>
    public const string ScopeTopic = "catchup.scope";

    /// <summary>
    /// What a Classic party's member who starts keeping the leader's story catches up with, see
    /// <see cref="CatchupEngine.Classic"/>: nothing while the story mapping has not come.
    /// </summary>
    public const string ClassicTopic = "catchup.classic";

    /// <summary>
    /// The side a player takes along in Iliasville, in either world type, see
    /// <see cref="SidePick.Answer"/>.
    /// </summary>
    public const string SideTopic = "catchup.side";

    /// <summary>
    /// Which classes of story keys are shared in a story, see <see cref="SidePick.SharedClasses"/>:
    /// the story ({"s", "v", "ss"}) in, a byte per class out, 1 for shared.
    /// </summary>
    public const string SharedTopic = "catchup.shared";

    /// <summary>
    /// The key items a Classic party's leader lends a member, see <see cref="KeyItemLoan.Answer"/>.
    /// </summary>
    public const string LoanTopic = "catchup.key_loan";

    /// <summary>
    /// The Medal King's gifts a Classic world's player is owed, see <see cref="MedalKingGift.Answer"/>:
    /// nothing while the story mapping has not come.
    /// </summary>
    public const string MedalKingTopic = "catchup.medal_king";

    /// <summary>
    /// Whether a Classic party's member plays the leader's story now, see <see cref="ClassicStory.Sync"/>.
    /// </summary>
    public const string SyncTopic = "catchup.classic_sync";

    /// <summary>
    /// Which members a Classic party's leader hears start or stop following their story, see
    /// <see cref="ClassicStory.Followers"/>.
    /// </summary>
    public const string FollowersTopic = "catchup.classic_followers";

    /// <summary>
    /// How a Classic party's member keeps the leader's story, see <see cref="ClassicStory.Mode"/>.
    /// </summary>
    public const string ModeTopic = "catchup.classic_mode";

    /// <summary>
    /// How a Classic party's member's own story is made once they leave the leader's, see
    /// <see cref="ClassicStory.Restore"/>.
    /// </summary>
    public const string RestoreTopic = "catchup.classic_restore";

    /// <summary>
    /// Registers the topics on a context, with an engine of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="tables">Reads the catch-up's tables of the story mapping held, <see langword="null"/> before it came.</param>
    /// <param name="party">Reads what a Classic member's catch-up reads of the party beyond its tables, <see langword="null"/> for <see cref="ClassicParty.None"/>.</param>
    /// <param name="level">Hears the player's level after each look, see <see cref="CatchupEngine.LevelTaken"/>.</param>
    /// <returns>The engine, for tests.</returns>
    public static CatchupEngine Register(BridgeContext context, Func<CatchupTables?> tables, Func<ClassicParty>? party = null, Action<StoryLevel>? level = null)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(tables);
        CatchupEngine engine = new() { LevelTaken = level };
        context.Register(KeysTopic, (_, _) => tables() is { } held ? CatchupEngine.Keys(held) : null);
        context.Register(CheckTopic, (_, request) => engine.Check(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(NoteTopic, (_, request) => engine.Note(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(HoldTopic, (_, request) => engine.HoldJoin(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(UnlocksTopic, (_, request) => engine.Unlocks(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(ScopeTopic, (_, request) => (tables() ?? CatchupTables.Empty).Scope.Answer(request.AsHash()));
        context.Register(ClassicTopic, (_, request) => CatchupEngine.Classic(tables() ?? CatchupTables.Empty, request.AsHash(), party?.Invoke() ?? ClassicParty.None));
        context.Register(SideTopic, (_, request) => SidePick.Answer(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(SharedTopic, (_, request) => RubyString.Binary(SidePick.SharedClasses(CatchupLook.StoryOf(request) ?? new StoryValues([], [], []))));
        context.Register(LoanTopic, (_, request) => KeyItemLoan.Answer(request.AsHash()));
        context.Register(MedalKingTopic, (_, request) => MedalKingGift.Answer(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(SyncTopic, (_, request) => ClassicStory.Sync(request.AsHash()));
        context.Register(FollowersTopic, (_, request) => ClassicStory.Followers(request.AsHash()));
        context.Register(ModeTopic, (_, request) => ClassicStory.Mode(request.AsHash()));
        context.Register(RestoreTopic, (_, request) => ClassicStory.Restore(request.AsHash()));
        return engine;
    }
}
