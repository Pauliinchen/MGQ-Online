//----------------------------------------------------------------
//  KeyScopes.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept a Classic party's world keys by the reviewed list instead of the Classic story's ranges
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Story;

/// <summary>
/// Who keeps a story key, and so whether a run that changes it reaches other players.
/// </summary>
public enum StoryScope : byte
{
    /// <summary>Each player's own: a run that changes it hands nothing over.</summary>
    Player = 0,

    /// <summary>The game's working value: each game keeps its own, and a replay never leaves one changed.</summary>
    Work = 1,

    /// <summary>A chest's key in a Classic party: each member's own copy, never mirrored; a run that changes it reaches the party.</summary>
    Party = 2,

    /// <summary>The story's: its owner's value, mirrored to everyone who keeps that story; a run that changes it reaches them.</summary>
    World = 3,

    /// <summary>A world value that crosses every track, through which no run reaches anyone.</summary>
    WholeWorld = 4,
}

/// <summary>
/// Reads the scope of every switch, variable and self switch from the one reviewed list, the
/// relay's story mapping, for both world types.
/// </summary>
public sealed class KeyScopes
{
    /// <summary>
    /// The list: work keys, chest switches, party chests, world chests and the world's keys.
    /// </summary>
    private readonly StoryTable _list;

    /// <summary>
    /// The self switches of every chest of the game (<c>party_chests</c>).
    /// </summary>
    private readonly HashSet<StoryKey> _partyChests;

    /// <summary>
    /// The self switches of the Raid World's chests (<c>chests</c>), which are the world's there.
    /// </summary>
    private readonly HashSet<StoryKey> _worldChests;

    /// <summary>
    /// Initializes the scopes.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="party">Whether chests are the party's, as in a Classic party.</param>
    private KeyScopes(StoryTable list, bool party)
    {
        _list = list;
        Party = party;
        _partyChests = [.. list.Catchup.PartyChests];
        _worldChests = party ? [] : [.. list.Catchup.Chests.Select(chest => chest.Key)];
    }

    /// <summary>
    /// Gets whether chests are the party's, as in a Classic party.
    /// </summary>
    public bool Party { get; }

    /// <summary>
    /// Makes the scopes of a Raid World, which has no party scope.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The scopes.</returns>
    public static KeyScopes Raid(StoryTable list) => new(list ?? throw new ArgumentNullException(nameof(list)), false);

    /// <summary>
    /// Makes the scopes of a Classic party.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The scopes.</returns>
    public static KeyScopes Classic(StoryTable list) => new(list ?? throw new ArgumentNullException(nameof(list)), true);

    /// <summary>
    /// Tells whether a run that changes a key of a scope reaches other players.
    /// </summary>
    /// <param name="scope">The scope.</param>
    /// <returns>Whether it does.</returns>
    public static bool HandsOver(StoryScope scope) => scope is StoryScope.Party or StoryScope.World;

    /// <summary>
    /// Tells whether a replay reads a key of a scope at the run's start, from its view.
    /// </summary>
    /// <param name="scope">The scope.</param>
    /// <returns>Whether it does: world and work keys, never the receiver's own things.</returns>
    public static bool InView(StoryScope scope) => scope is StoryScope.Work or StoryScope.World or StoryScope.WholeWorld;

    /// <summary>
    /// Finds who keeps a key: a work key the game; a chest's key the party in a Classic party and
    /// each player in a Raid World, but a Raid world chest the world; any other key by the class
    /// the list gives it.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="site">Where the write came from, which a common event's self switch rule reads; <see langword="null"/> for none.</param>
    /// <returns>The scope.</returns>
    public StoryScope ScopeOf(StoryKey key, string? site = null)
    {
        if (_list.Work.Contains(key))
        {
            return StoryScope.Work;
        }

        if (_worldChests.Contains(key))
        {
            return StoryScope.World;
        }

        if (IsChestKey(key))
        {
            return Party ? StoryScope.Party : StoryScope.Player;
        }

        return ScopeOfClass(_list.ClassOf(key, site));
    }

    /// <summary>
    /// Writes the scopes as the scripts look keys up: a scope byte per switch and per variable, the
    /// self switches named one by one, then the self switch rules, the indexed events and the
    /// default, walked as <see cref="StoryTable.ClassOf"/> walks them.
    /// </summary>
    /// <returns>The table.</returns>
    public ScopeTable Table()
    {
        byte[] switches = new byte[_list.Switches.Length];
        for (int id = 0; id < switches.Length; id++)
        {
            switches[id] = (byte)ScopeOf(StoryKey.Switch(id));
        }

        byte[] variables = new byte[_list.Variables.Length];
        for (int id = 0; id < variables.Length; id++)
        {
            variables[id] = (byte)ScopeOf(StoryKey.Variable(id));
        }

        var keys = new Dictionary<StoryKey, StoryScope>();
        foreach (StoryKey key in _partyChests.Concat(_worldChests))
        {
            keys[key] = ScopeOf(key);
        }

        var rules = _list.SelfRules.ToDictionary(rule => rule.Key, rule => ScopeOfClass(rule.Value), StringComparer.Ordinal);
        return new ScopeTable(switches, variables, keys, rules, _list.Index, ScopeOfClass(_list.SelfDefault));
    }

    /// <summary>
    /// Finds the scope of a key that is no work key and no chest's by its class.
    /// </summary>
    /// <param name="found">The class.</param>
    /// <returns>The scope: kept keys the world's, the rest each player's own.</returns>
    private static StoryScope ScopeOfClass(StoryClass found) =>
        !found.HasFlag(StoryClass.Kept) ? StoryScope.Player : found.HasFlag(StoryClass.WholeWorld) ? StoryScope.WholeWorld : StoryScope.World;

    /// <summary>
    /// Tells whether a key is a chest's: a self switch of <c>party_chests</c> or a switch of kind <c>chest</c>.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Whether it is.</returns>
    private bool IsChestKey(StoryKey key) => key.Kind switch
    {
        StoryKeyKind.SelfSwitch => _partyChests.Contains(key),
        StoryKeyKind.Switch => _list.ClassOf(key).HasFlag(StoryClass.Chest),
        _ => false,
    };
}

/// <summary>
/// The scopes as the scripts look keys up.
/// </summary>
/// <param name="Switches">The scope of each switch by id; an id past the end is each player's own.</param>
/// <param name="Variables">The scope of each variable by id; an id past the end is each player's own.</param>
/// <param name="Keys">The self switches named one by one, which go before any rule.</param>
/// <param name="SelfRules">The self switch rules by key, as <see cref="StoryTable.SelfRules"/>.</param>
/// <param name="Index">The events whose self switches are the world's without a rule.</param>
/// <param name="SelfDefault">The scope of a self switch nothing names.</param>
public sealed record ScopeTable(
    byte[] Switches,
    byte[] Variables,
    IReadOnlyDictionary<StoryKey, StoryScope> Keys,
    IReadOnlyDictionary<string, StoryScope> SelfRules,
    IReadOnlySet<long> Index,
    StoryScope SelfDefault);
