//----------------------------------------------------------------
//  EventCodes.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Frozen;
using System.Collections.Generic;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The event command codes the rules read, as RPG Maker VX Ace numbers them.
/// </summary>
public static class EventCodes
{
    /// <summary>Show Text: a page of dialogue.</summary>
    public const int ShowText = 101;

    /// <summary>Show Choices.</summary>
    public const int ShowChoices = 102;

    /// <summary>Input Number, which writes a variable.</summary>
    public const int InputNumber = 103;

    /// <summary>Select Key Item, which writes a variable.</summary>
    public const int SelectKeyItem = 104;

    /// <summary>Show Scrolling Text.</summary>
    public const int ScrollingText = 105;

    /// <summary>Conditional Branch.</summary>
    public const int Branch = 111;

    /// <summary>Call Common Event.</summary>
    public const int CallCommonEvent = 117;

    /// <summary>Label.</summary>
    public const int Label = 118;

    /// <summary>Jump to Label.</summary>
    public const int JumpToLabel = 119;

    /// <summary>Control Switches.</summary>
    public const int ControlSwitches = 121;

    /// <summary>Control Variables.</summary>
    public const int ControlVariables = 122;

    /// <summary>Control Self Switch.</summary>
    public const int ControlSelfSwitch = 123;

    /// <summary>Change Gold.</summary>
    public const int ChangeGold = 125;

    /// <summary>Change Items.</summary>
    public const int ChangeItems = 126;

    /// <summary>Change Weapons.</summary>
    public const int ChangeWeapons = 127;

    /// <summary>Change Armors.</summary>
    public const int ChangeArmors = 128;

    /// <summary>Change Party Member.</summary>
    public const int ChangePartyMember = 129;

    /// <summary>Transfer Player.</summary>
    public const int TransferPlayer = 201;

    /// <summary>Set Vehicle Location.</summary>
    public const int SetVehicleLocation = 202;

    /// <summary>Set Event Location.</summary>
    public const int SetEventLocation = 203;

    /// <summary>Get On/Off Vehicle.</summary>
    public const int GetOnOffVehicle = 206;

    /// <summary>Get Location Info, which writes a variable.</summary>
    public const int GetLocationInfo = 285;

    /// <summary>Battle Processing.</summary>
    public const int Battle = 301;

    /// <summary>Name Input Processing.</summary>
    public const int NameInput = 303;

    /// <summary>Game Over.</summary>
    public const int GameOver = 353;

    /// <summary>Return to Title Screen.</summary>
    public const int ReturnToTitle = 354;

    /// <summary>Script, its first line.</summary>
    public const int Script = 355;

    /// <summary>When [choice]: the branch of one choice.</summary>
    public const int ChoiceBranch = 402;

    /// <summary>When Cancel: the branch of cancelling a choice.</summary>
    public const int CancelBranch = 403;

    /// <summary>Else, of a conditional branch.</summary>
    public const int Else = 411;

    /// <summary>Branch End.</summary>
    public const int BranchEnd = 412;

    /// <summary>A script's continuation line.</summary>
    public const int ScriptLine = 655;

    /// <summary>
    /// The codes whose parameters the rules read; the reader leaves out every other command's, such
    /// as the dialogue's lines, which make most of the game's event data.
    /// </summary>
    private static readonly FrozenSet<int> ParameterCodes = new HashSet<int>
    {
        InputNumber, SelectKeyItem, Branch, CallCommonEvent, Label, JumpToLabel, ControlSwitches, ControlVariables,
        ControlSelfSwitch, ChangeGold, ChangeItems, ChangeWeapons, ChangeArmors, TransferPlayer, SetVehicleLocation,
        SetEventLocation, GetLocationInfo, Battle, Script, ScriptLine,
    }.ToFrozenSet();

    /// <summary>
    /// Tells whether the reader keeps a command's parameters.
    /// </summary>
    /// <param name="code">The command's code.</param>
    /// <returns>Whether a rule reads them.</returns>
    public static bool KeepsParameters(int code) => ParameterCodes.Contains(code);
}
