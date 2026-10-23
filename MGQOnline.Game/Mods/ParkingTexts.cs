//----------------------------------------------------------------
//  ParkingTexts.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Named the mods through SharedSettings.ListText
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Mods;

/// <summary>
/// What the game tells the player while it turns other mods off and back on.
/// </summary>
public static class ParkingTexts
{
    /// <summary>
    /// Most mods a question names before it counts the rest.
    /// </summary>
    public const int NamedMods = 3;

    /// <summary>
    /// What the world screen says while the catalog, which tells the personal mods, is unknown.
    /// </summary>
    public const string Catalog = "The mod catalog has not loaded yet. Try again in a moment.";

    /// <summary>
    /// What the game says when another game of this folder keeps the mods turned off.
    /// </summary>
    public const string Held = "Another game of this folder has mods turned off. They come back when it closes.";

    /// <summary>
    /// What the game says when the player saves while the session runs without their other mods.
    /// </summary>
    public const string SaveOff = "Saving is off until your other mods are back. Start the game again to bring them back.";

    /// <summary>
    /// What the box on the title screen says as the player left a world that turned other mods off.
    /// </summary>
    public const string Leave = "Your mods are back after a restart.";

    /// <summary>
    /// What the box says at the first start after the game closed while mods were parked.
    /// </summary>
    public const string Recovered = "The game closed while mods were turned off. Your mods are back after a restart.";

    /// <summary>
    /// What the box says when a restore failed.
    /// </summary>
    public const string NotBack = "Some of your mods could not be turned back on. They wait in the game folder's Parked mods, and the game tries again at its next start.";

    /// <summary>
    /// What the box says when the game cannot start again by itself.
    /// </summary>
    public const string RestartByHand = "Your mods are back once you start the game again. Close it and start it again.";

    /// <summary>
    /// Asks whether to park mods and enter a world, or to put the parked ones back for it.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <param name="plan">The scripts to park, none to put every parked one back.</param>
    /// <returns>The question.</returns>
    public static string Confirm(string world, IReadOnlyList<string> plan) => plan.Count == 0
        ? $"{world} allows your turned-off mods, which come back after a restart. Restart and join?"
        : $"These mods are turned off while you play in {world}: {ListText(plan)}. Restart and join?";

    /// <summary>
    /// Tells what the offer to download a world's mods parks too.
    /// </summary>
    /// <param name="plan">The scripts to park, none when nothing more is parked.</param>
    /// <returns>The sentence with a space in front, empty when nothing more is parked.</returns>
    public static string Also(IReadOnlyList<string> plan) =>
        plan.Count > 0 ? $" These mods are turned off while you play there: {ListText(plan)}." : string.Empty;

    /// <summary>
    /// Tells why scripts behind a link to another drive keep the game out of a world.
    /// </summary>
    /// <param name="stuck">The scripts.</param>
    /// <returns>How many there are and the first one's path.</returns>
    public static string Elsewhere(IReadOnlyList<string> stuck) => stuck.Count == 1
        ? $"1 mod script lies on another drive behind a link in Patch and cannot be turned off: {stuck[0]}."
        : string.Create(CultureInfo.InvariantCulture, $"{stuck.Count} mod scripts lie on another drive behind a link in Patch and cannot be turned off: {(stuck.Count > 0 ? stuck[0] : string.Empty)}.");

    /// <summary>
    /// Tells that the Patch folder could not be read.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string Unlisted(string world) => $"Your Patch folder could not be read, so you cannot enter {world} now. See the log.";

    /// <summary>
    /// Tells that mods were moved since the game started.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string RestartFirst(string world) => $"Your mods were turned off or on since the game started. Restart it first, then enter {world}.";

    /// <summary>
    /// Asks the creator of a world whose data scan was made with the mods it turns off still on.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The question.</returns>
    public static string OwnData(string world) => $"The data scan of {world} was made with your other mods on. Take your game's data as it is now and enter?";

    /// <summary>
    /// Tells that the mods could not be moved.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string ParkFailed(string world) => $"Your other mods could not be turned off, so you cannot enter {world} now. See the log.";

    /// <summary>
    /// Tells that the game could not start again.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string RestartFailed(string world) => $"The game could not start again, so your mods stay on and {world} was not entered.";

    /// <summary>
    /// Tells that a world's downloaded mods were installed, but the other mods could not be turned off
    /// or kept off for the restart.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string NotKept(string world) => $"The mods were installed, but your other mods could not be turned off or kept off for {world}. Try again.";

    /// <summary>
    /// Tells that a world's downloaded mods were installed, but the parked mods it allows could not be
    /// turned back on for the restart.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string NotBackOn(string world) => $"The mods were installed, but your other mods could not be turned back on for {world}. Try again.";

    /// <summary>
    /// Tells the player to start the game again by hand for downloaded mods.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string StartByHand(string world) => $"The mods were installed. Close the game and start it again to enter {world}.";

    /// <summary>
    /// Tells a player in a world that now turns other mods off.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string NowOff(string world) => $"{world} now turns off other mods. Enter it again to play.";

    /// <summary>
    /// Adds how many mods the last restore sent to the conflicts folder.
    /// </summary>
    /// <param name="text">What the title screen says.</param>
    /// <param name="conflicts">How many went there.</param>
    /// <returns>The text, with the sentence on the conflicts after it when there were any.</returns>
    public static string WithConflicts(string text, int conflicts) => conflicts > 0
        ? string.Create(CultureInfo.InvariantCulture, $"{text} {conflicts} of your mods went to Parked mods/Conflicts because another file took their place in Patch.")
        : text;

    /// <summary>
    /// Names a few of the mods scripts belong to and counts the rest.
    /// </summary>
    /// <param name="paths">The scripts.</param>
    /// <returns>Such as "Invasions, Level_Cap and 2 more".</returns>
    public static string ListText(IEnumerable<string> paths) => SharedSettings.ListText(ParkingRules.ModsOf(paths).Select(mod => mod.Name).ToList(), NamedMods);
}
