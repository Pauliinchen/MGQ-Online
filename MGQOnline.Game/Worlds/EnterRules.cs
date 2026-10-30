//----------------------------------------------------------------
//  EnterRules.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Stopped asking the creator of a world entered with mods parked, since none are parked any more
//                            - Decided entering a world whose data scan has another format
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// One thing the world screen does while a world is entered, as the rules decide it: say a text,
/// buzz, go back to the list, ask to confirm, offer choices, fetch the starting save or start the
/// world.
/// </summary>
/// <param name="Kind">What: <see cref="EnterRules.Say"/>, <see cref="EnterRules.Buzz"/>,
/// <see cref="EnterRules.Back"/>, <see cref="EnterRules.Confirm"/>, <see cref="EnterRules.Choices"/>,
/// <see cref="EnterRules.Fetch"/> or <see cref="EnterRules.Start"/>.</param>
/// <param name="Text">What is said or asked, <see langword="null"/> when nothing is.</param>
/// <param name="What">What a confirmation is about, such as "differing".</param>
/// <param name="Yes">The command that confirms.</param>
/// <param name="Offered">The choices offered, each label with its answer.</param>
public sealed record EnterDone(string Kind, string? Text = null, string? What = null, string? Yes = null, IReadOnlyList<(string Label, string Answer)>? Offered = null);

/// <summary>
/// The rules the world screen enters a world by, as world_screen.rbx and world_save_distribution.rbx
/// had them: whether the world takes players now, whether this game's data may enter, and where a
/// new player starts.
/// </summary>
public static class EnterRules
{
    /// <summary>
    /// Says a text in the screen's lines.
    /// </summary>
    public const string Say = "say";

    /// <summary>
    /// Plays the buzzer.
    /// </summary>
    public const string Buzz = "buzz";

    /// <summary>
    /// Goes back to the list.
    /// </summary>
    public const string Back = "back";

    /// <summary>
    /// Asks to confirm.
    /// </summary>
    public const string Confirm = "confirm";

    /// <summary>
    /// Offers where to start.
    /// </summary>
    public const string Choices = "choices";

    /// <summary>
    /// Fetches the world's starting save, then starts it.
    /// </summary>
    public const string Fetch = "fetch";

    /// <summary>
    /// Starts the world from its latest save, or at the beginning without one.
    /// </summary>
    public const string Start = "start";

    /// <summary>
    /// What a new player is told before taking a creator's save; it fits the two lines the message has.
    /// </summary>
    public const string StartWarning = "This world starts from its creator's save. A save can run code on your PC; take it only from creators you trust.";

    /// <summary>
    /// The answer that cancels a question.
    /// </summary>
    public const string Cancel = "cancel";

    /// <summary>
    /// The starting save of a world whose creator still uploads it.
    /// </summary>
    private const string Pending = "pending";

    /// <summary>
    /// The starting save of a world that has one ready.
    /// </summary>
    private const string Ready = "ready";

    /// <summary>
    /// Decides whether a world takes players now: not while its creator still sets up its starting
    /// save, nor while it is full.
    /// </summary>
    /// <remarks>
    /// The relay may still count the player online for a moment after they left, so they do not take
    /// a seat of their own.
    /// </remarks>
    /// <param name="name">The world's name.</param>
    /// <param name="start">How far it is with its starting save.</param>
    /// <param name="online">The players online.</param>
    /// <param name="seats">Its seats.</param>
    /// <param name="meOnline">Whether the list counts this player online in it.</param>
    /// <returns>What the screen does to refuse, <see langword="null"/> when it takes players now.</returns>
    public static IReadOnlyList<EnterDone>? OpenNow(string name, string start, int online, int seats, bool meOnline)
    {
        if (start == Pending)
        {
            return Refused($"{name} is still being set up by its creator. Try again in a moment.");
        }

        return online - (meOnline ? 1 : 0) >= seats ? Refused($"{name} is full right now.") : null;
    }

    /// <summary>
    /// Decides whether this game may enter a world as far as its data goes: one whose data differs
    /// from the creator's is kept out of a world for the same data only, and otherwise asked first.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="differing">The parts of the data that differ, <see langword="null"/> when they cannot be compared.</param>
    /// <param name="strict">Whether only games with the same data may enter.</param>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="own">Whether the player made the world.</param>
    /// <param name="accepted">Whether the player said to enter anyway.</param>
    /// <returns>Whether entering goes on, and what the screen does otherwise.</returns>
    public static (bool Allowed, IReadOnlyList<EnterDone> Did) Data(string name, IReadOnlyList<string>? differing, bool strict, string? mods, bool own, bool accepted)
    {
        if (differing == null || differing.Count == 0)
        {
            return (true, []);
        }

        if (accepted && !strict)
        {
            return (true, []);
        }

        IReadOnlyList<string> needed = ModsText.Names(mods);
        string needs = needed.Count == 0 ? "" : $" It needs: {string.Join(", ", needed)}.";
        if (strict)
        {
            return (false, Refused(own ? $"{name} only takes matching game data. Update it under Your game in its details." : $"{name} only takes matching game data.{needs}"));
        }

        return (false, [new EnterDone(Confirm, $"Your game data differs.{needs} Enter anyway?", "differing", "Enter anyway")]);
    }

    /// <summary>
    /// Decides whether this game may enter a world whose data scan another version of the mod made,
    /// which cannot be compared: its creator is asked to take their game's data first, and other
    /// games are kept out of a world for the same data only until the creator did.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="strict">Whether only games with the same data may enter.</param>
    /// <param name="own">Whether the player made the world.</param>
    /// <returns>Whether entering goes on, and what the screen does otherwise.</returns>
    public static (bool Allowed, IReadOnlyList<EnterDone> Did) OtherScan(string name, bool strict, bool own)
    {
        if (own)
        {
            return (false, [new EnterDone(Confirm, $"The data scan of {name} was made by another version of the mod. Take your game's data as it is now and enter?", "own_data", "Update and enter")]);
        }

        return strict ? (false, Refused($"{name} only takes matching game data. Its data scan waits for its creator to update it.")) : (true, []);
    }

    /// <summary>
    /// Decides where a player starts in a world this PC has a folder of: asked where while new to a
    /// Classic world whose players choose, warned before a creator's save they did not make, or
    /// started from the latest save here, or at the beginning without one.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="raid">Whether it is a Raid World, whose players never choose.</param>
    /// <param name="choose">Whether its players choose where to start, <see langword="null"/> when the list does not tell.</param>
    /// <param name="start">How far it is with its starting save, <see langword="null"/> when the list does not tell.</param>
    /// <param name="newPlayer">Whether this PC has no save of it yet.</param>
    /// <param name="own">Whether the player made it, whose own save is no risk to them.</param>
    /// <returns>What the screen does.</returns>
    public static IReadOnlyList<EnterDone> StartOf(string name, bool raid, bool? choose, string? start, bool newPlayer, bool own)
    {
        if (choose == true && !raid && newPlayer)
        {
            return Where(name, start);
        }

        if (start == Ready && newPlayer)
        {
            return own ? [new EnterDone(Fetch)] : Warning();
        }

        return [new EnterDone(Start)];
    }

    /// <summary>
    /// Asks a new player of a world whose players choose where to start.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="start">How far it is with its starting save, which offers the creator's only when ready.</param>
    /// <returns>The question and its choices.</returns>
    public static IReadOnlyList<EnterDone> Where(string name, string? start)
    {
        List<(string, string)> offered = start == Ready ? [("From the creator's save", "from_creator")] : [];
        offered.AddRange([("At the beginning", "from_beginning"), ("From one of my saves", "from_own"), ("Back", Cancel)]);
        return [new EnterDone(Say, $"Where do you start in {name}? A save cannot be undone."), new EnterDone(Choices, Offered: offered)];
    }

    /// <summary>
    /// Warns a new player that a world's starting save can run code on their PC before they take it.
    /// </summary>
    /// <returns>The warning and its choices.</returns>
    public static IReadOnlyList<EnterDone> Warning() =>
        [new EnterDone(Say, StartWarning), new EnterDone(Choices, Offered: [("Take", "take_start"), ("Start at the beginning", "from_beginning"), ("Back", Cancel)])];

    /// <summary>
    /// Refuses with a text: the buzzer, the text, and back to the list.
    /// </summary>
    /// <param name="text">Why.</param>
    /// <returns>What the screen does.</returns>
    public static IReadOnlyList<EnterDone> Refused(string text) => [new EnterDone(Buzz), new EnterDone(Say, text), new EnterDone(Back)];
}
