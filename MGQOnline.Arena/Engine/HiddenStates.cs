//----------------------------------------------------------------
//  HiddenStates.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the stance states
//                            - Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The ids of the states the engine gives a boss where the game's reader makes a state of its own:
/// a trait block's state recipes, such as a Last stand's phase, and a stance's hidden state.
/// </summary>
/// <remarks>The ids lie below 0, where no state of the game's database lies, so a game state never meets them.</remarks>
public static class HiddenStates
{
    /// <summary>
    /// The id of the first custom skill's stance state; the recipes' ids lie above it.
    /// </summary>
    private const int StanceBase = -100_000;

    /// <summary>
    /// Gives the id of a trait block's state recipe.
    /// </summary>
    /// <param name="index">The recipe's index, as <c>{state:N}</c> names it.</param>
    /// <returns>The id: -1 for recipe 0, -2 for recipe 1, and so on.</returns>
    public static int OfRecipe(int index) => -1 - index;

    /// <summary>
    /// Gives the id of the hidden state a custom skill's stance arms its counter with.
    /// </summary>
    /// <param name="customIndex">The custom skill's place in the custom order.</param>
    /// <returns>The id: -100000 for the first custom skill, -100001 for the second, and so on.</returns>
    public static int OfStance(int customIndex) => StanceBase - customIndex;
}
