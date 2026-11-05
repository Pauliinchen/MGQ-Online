//----------------------------------------------------------------
//  EventSorterTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-05: Found the battlefuck events the page calls in the game's own common events
//      Paulinchen  2026-10-31: Checked that a weapon's pedestal that hands out a medal by script is a chest
//      Paulinchen  2026-10-28: Sorted the game cases and the tiny game from the events database
//                            - Classified the hand-made lists
//                            - Sorted over event sources
//      Paulinchen  2026-10-23: Checked that a page calling a battlefuck event is the player's own
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the event sorter over lists a test writes.
/// </summary>
public sealed class EventSorterTests
{
    /// <summary>
    /// Asserts that a page that can now call a battlefuck event is the player's own, though it moves
    /// the story on, while a quest page whose battlefuck waits in another step's branch stays story.
    /// </summary>
    [Fact]
    public void KindOf_SortsAPageThatCallsABattlefuckAsThePlayersOwn()
    {
        var sorter = new EventSorter(EventDatabases.SourceOf(new TinyGame().Common(6999).Common(7001, TinyGame.C(EventCodes.CallCommonEvent, 6999))));
        var state = new QuietState();
        EventCommand[] battlefuck = CommandClassifier.Classify([Command(EventCodes.ShowText, 0, "", 0, 0, 2), Command(EventCodes.ControlSwitches, 0, 60, 60, 0), Command(EventCodes.CallCommonEvent, 0, 7001)]);
        EventCommand[] other = CommandClassifier.Classify([Command(EventCodes.CallCommonEvent, 0, 6998), Command(EventCodes.ControlSwitches, 0, 60, 60, 0)]);
        EventCommand[] questStep = CommandClassifier.Classify(
        [
            Command(EventCodes.Branch, 0, 1, 1028, 0, 4, 0), Command(EventCodes.CallCommonEvent, 1, 7001), Command(0, 1), Command(EventCodes.BranchEnd, 0),
            Command(EventCodes.ShowText, 0, "", 0, 0, 2), Command(EventCodes.ControlVariables, 0, 1028, 1028, 0, 0, 6),
        ]);

        Assert.Equal(EventKind.Own, sorter.KindOf(battlefuck, state));
        Assert.Equal(EventKind.Story, sorter.KindOf(other, state));
        Assert.Equal(EventKind.Story, sorter.KindOf(questStep, state));
    }

    /// <summary>
    /// Asserts that a weapon's pedestal that hands out a medal by script is a chest.
    /// </summary>
    [Fact]
    public void KindOf_SortsAWeaponPedestalThatHandsOutAMedalAsAChest()
    {
        var sorter = new EventSorter(EventDatabases.SourceOf(new TinyGame()));
        EventCommand[] pedestal = CommandClassifier.Classify(
        [
            Command(EventCodes.ShowText, 0, "", 0, 0, 2), Command(EventCodes.ChangeWeapons, 0, 4168, 0, 0, 1),
            Command(EventCodes.ControlSelfSwitch, 0, "A", 0), Command(EventCodes.Script, 0, "gain_medal(104)"),
        ]);

        Assert.Equal(EventKind.Chest, sorter.KindOf(pedestal, new QuietState()));
    }

    /// <summary>
    /// Makes a command of plain parameters.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="indent">The indent.</param>
    /// <param name="parameters">The parameters, numbers and texts.</param>
    /// <returns>The command, as read.</returns>
    private static RawCommand Command(int code, int indent, params object[] parameters) =>
        new(code, indent, new RubyArray(parameters.Select(parameter => parameter is string text ? (RubyValue)text : (RubyValue)(long)(int)parameter)));

    /// <summary>
    /// Live values that hold nothing: every switch off, every variable 0, nothing personal.
    /// </summary>
    private sealed class QuietState : IEventState
    {
        /// <inheritdoc />
        public bool Switch(long id) => false;

        /// <inheritdoc />
        public long? Variable(long id) => 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;
    }
}
