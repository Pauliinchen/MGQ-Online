//----------------------------------------------------------------
//  FlowRest.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Flow;

/// <summary>
/// One command of an event's list as the flow guard reads it.
/// </summary>
/// <param name="Code">The command's code, as RPG Maker VX Ace numbers it.</param>
/// <param name="Numbers">Its whole number parameters in their order, 0 for one that is none.</param>
/// <param name="Text">Its first text parameter, empty for none.</param>
/// <param name="Tone">The tint a Change Screen Tone sets, <see langword="null"/> for any other command.</param>
public sealed record FlowCommand(int Code, IReadOnlyList<long> Numbers, string Text, FlowTone? Tone)
{
    /// <summary>
    /// Reads a parameter as a whole number.
    /// </summary>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The number; 0 for one that is missing.</returns>
    public long Number(int index) => index < Numbers.Count ? Numbers[index] : 0;
}

/// <summary>
/// What the commands an event would still run leave of the game's flow, in their order, through
/// the common events they call: whether they fade the screen in, the last tint they set, the pictures
/// they leave erased, whether they leave the player's character hidden and the followers shown,
/// whether they leave a temporary party, and the bans they leave on or off.
/// </summary>
/// <remarks>
/// The commands of every branch count as if each ran, since which branch runs depends on values the
/// guard does not hold; what the last of them sets is what the rest leaves.
/// </remarks>
public sealed class FlowRest
{
    /// <summary>
    /// How deep the reader follows calls of common events, which a common event calling itself would
    /// otherwise follow for good.
    /// </summary>
    public const int MaxDepth = 8;

    /// <summary>Call Common Event.</summary>
    private const int CallCommonEvent = 117;

    /// <summary>Control Switches.</summary>
    private const int ControlSwitches = 121;

    /// <summary>Change Save Access.</summary>
    private const int ChangeSaveAccess = 134;

    /// <summary>Change Menu Access.</summary>
    private const int ChangeMenuAccess = 135;

    /// <summary>Change Encounter.</summary>
    private const int ChangeEncounter = 136;

    /// <summary>Change Formation Access.</summary>
    private const int ChangeFormationAccess = 137;

    /// <summary>Change Transparency.</summary>
    private const int ChangeTransparency = 211;

    /// <summary>Change Player Followers.</summary>
    private const int ChangeFollowers = 216;

    /// <summary>Fadein Screen.</summary>
    private const int FadeinScreen = 222;

    /// <summary>Tint Screen.</summary>
    private const int TintScreen = 223;

    /// <summary>Show Picture.</summary>
    private const int ShowPicture = 231;

    /// <summary>Erase Picture.</summary>
    private const int ErasePicture = 235;

    /// <summary>Script, its first line.</summary>
    private const int Script = 355;

    /// <summary>A script's continuation line.</summary>
    private const int ScriptLine = 655;

    /// <summary>
    /// The value of a switch command, an access or a character command that turns its setting on.
    /// </summary>
    private const long On = 0;

    /// <summary>
    /// What a script calls to fade the screen in, as the game's own scenes do through scripts too.
    /// </summary>
    private const string FadeInCall = "fadein";

    /// <summary>
    /// What a script calls to end a story's temporary party.
    /// </summary>
    private const string ReleasePartyCall = "release_temp_actors";

    /// <summary>
    /// What a script calls to start a story's temporary party.
    /// </summary>
    private const string SetPartyCall = "set_temp_actors";

    /// <summary>
    /// The last action on each picture: <see langword="true"/> for shown, <see langword="false"/> for erased.
    /// </summary>
    private readonly Dictionary<int, bool> _pictures = [];

    /// <summary>
    /// The last state each ban was set to.
    /// </summary>
    private readonly Dictionary<string, bool> _bans = [];

    /// <summary>
    /// The common events called that the reader was not given.
    /// </summary>
    private readonly List<int> _needs = [];

    /// <summary>
    /// Initializes a new instance of the <see cref="FlowRest"/> class with no command read.
    /// </summary>
    private FlowRest()
    {
    }

    /// <summary>
    /// Gets a value indicating whether the commands fade the screen in.
    /// </summary>
    public bool FadesIn { get; private set; }

    /// <summary>
    /// Gets the last tint the commands set, <see langword="null"/> for none.
    /// </summary>
    public FlowTone? Tone { get; private set; }

    /// <summary>
    /// Gets whether the commands leave the player's character hidden, <see langword="null"/> when they do not set it.
    /// </summary>
    public bool? Hidden { get; private set; }

    /// <summary>
    /// Gets whether the commands leave the followers shown, <see langword="null"/> when they do not set it.
    /// </summary>
    public bool? Followers { get; private set; }

    /// <summary>
    /// Gets whether the commands leave a temporary party, <see langword="null"/> when they neither start nor end one.
    /// </summary>
    public bool? TempParty { get; private set; }

    /// <summary>
    /// Gets the common events the commands call that the reader was not given, whose commands it needs.
    /// </summary>
    public IReadOnlyList<int> Needs => _needs;

    /// <summary>
    /// Reads what commands leave of the flow.
    /// </summary>
    /// <param name="commands">The commands, in their order.</param>
    /// <param name="common">Gives a common event's commands by its id, <see langword="null"/> for one the reader is not given.</param>
    /// <returns>What they leave.</returns>
    public static FlowRest Of(IReadOnlyList<FlowCommand> commands, Func<int, IReadOnlyList<FlowCommand>?> common)
    {
        ArgumentNullException.ThrowIfNull(commands);
        ArgumentNullException.ThrowIfNull(common);
        var rest = new FlowRest();
        rest.Read(commands, common, new HashSet<int>(), 0);
        return rest;
    }

    /// <summary>
    /// Tells whether the commands leave a picture erased.
    /// </summary>
    /// <param name="number">The picture's number.</param>
    /// <returns>Whether the last of them that touches it erases it.</returns>
    public bool Erases(int number) => _pictures.TryGetValue(number, out bool shown) && !shown;

    /// <summary>
    /// Tells whether the commands leave a ban lifted.
    /// </summary>
    /// <param name="ban">The ban, see <see cref="FlowBans"/>.</param>
    /// <returns>Whether the last of them that sets it lifts it.</returns>
    public bool Lifts(string ban) => _bans.TryGetValue(ban, out bool on) && !on;

    /// <summary>
    /// Reads commands into what they leave.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <param name="common">Gives a common event's commands.</param>
    /// <param name="calling">The common events that call down to these commands.</param>
    /// <param name="depth">How many calls deep they stand.</param>
    private void Read(IReadOnlyList<FlowCommand> commands, Func<int, IReadOnlyList<FlowCommand>?> common, HashSet<int> calling, int depth)
    {
        foreach (FlowCommand command in commands)
        {
            switch (command.Code)
            {
                case CallCommonEvent:
                    Call((int)command.Number(0), common, calling, depth);
                    break;
                case ControlSwitches when command.Number(0) <= ClassicStoryTable.EscapeBan && ClassicStoryTable.EscapeBan <= command.Number(1):
                    _bans[FlowBans.Escape] = command.Number(2) == On;
                    break;
                case ChangeSaveAccess:
                    _bans[FlowBans.Save] = command.Number(0) == On;
                    break;
                case ChangeMenuAccess:
                    _bans[FlowBans.Menu] = command.Number(0) == On;
                    break;
                case ChangeEncounter:
                    _bans[FlowBans.Encounter] = command.Number(0) == On;
                    break;
                case ChangeFormationAccess:
                    _bans[FlowBans.Formation] = command.Number(0) == On;
                    break;
                case ChangeTransparency:
                    Hidden = command.Number(0) == On;
                    break;
                case ChangeFollowers:
                    Followers = command.Number(0) == On;
                    break;
                case FadeinScreen:
                    FadesIn = true;
                    break;
                case TintScreen when command.Tone is { } tone:
                    Tone = tone;
                    break;
                case ShowPicture:
                    _pictures[(int)command.Number(0)] = true;
                    break;
                case ErasePicture:
                    _pictures[(int)command.Number(0)] = false;
                    break;
                case Script or ScriptLine:
                    ReadScript(command.Text);
                    break;
            }
        }
    }

    /// <summary>
    /// Reads a call of a common event: its commands, once it is given and calls no caller of its own.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <param name="common">Gives a common event's commands.</param>
    /// <param name="calling">The common events that call down to this call.</param>
    /// <param name="depth">How many calls deep the call stands.</param>
    private void Call(int id, Func<int, IReadOnlyList<FlowCommand>?> common, HashSet<int> calling, int depth)
    {
        if (depth >= MaxDepth || calling.Contains(id))
        {
            return;
        }

        if (common(id) is not { } commands)
        {
            if (!_needs.Contains(id))
            {
                _needs.Add(id);
            }

            return;
        }

        calling.Add(id);
        Read(commands, common, calling, depth + 1);
        calling.Remove(id);
    }

    /// <summary>
    /// Reads a line of a script for the fades and temporary parties it starts or ends.
    /// </summary>
    /// <param name="text">The line.</param>
    private void ReadScript(string text)
    {
        if (text.Contains(FadeInCall, StringComparison.OrdinalIgnoreCase))
        {
            FadesIn = true;
        }

        if (text.Contains(ReleasePartyCall, StringComparison.Ordinal))
        {
            TempParty = false;
        }
        else if (text.Contains(SetPartyCall, StringComparison.Ordinal))
        {
            TempParty = true;
        }
    }
}
