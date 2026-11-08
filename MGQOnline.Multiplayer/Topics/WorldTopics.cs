//----------------------------------------------------------------
//  WorldTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Named the Formation sizes for the forms too
//                            - Left reading and writing squad settings to the topics both hosts answer
//                            - Created
//
//----------------------------------------------------------------

using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Squads;
using MGQOnline.Game.Topics;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts ask the rules of a world: its seats, difficulties,
/// squad settings and the seats its code tells. Reading and writing squad settings is
/// <see cref="SquadTopics"/>'s, which the battle server answers too.
/// </summary>
internal static class WorldTopics
{
    /// <summary>
    /// Hands out the limits and defaults of a world's settings: nothing in; <c>seats</c> (<c>min</c>,
    /// <c>max</c>, <c>default</c>), <c>difficulties</c> ([value, name] each), <c>difficulty</c> (the
    /// default), <c>formations</c> ([size, name] each), <c>fronts</c> and <c>squad</c> (the default
    /// squad settings, as <see cref="SquadTopics.Read"/> answers them) out.
    /// </summary>
    public const string Rules = "world.rules";

    /// <summary>
    /// Reads a world code, see <see cref="WorldCode"/>: <c>code</c> and, to change them, <c>seats</c>
    /// in; <c>code</c> and <c>seats</c> out, the code with the new seats when they are in range; nil
    /// for a text that is no world code.
    /// </summary>
    public const string Code = "world.code";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(Rules, (_, _) => RulesValue());
        context.Register(Code, (_, request) => CodeOf(request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Rules"/>.
    /// </summary>
    /// <returns>The limits and defaults.</returns>
    private static RubyHash RulesValue() => new()
    {
        { "seats", new RubyHash { { "min", WorldCode.MinSeats }, { "max", WorldCode.MaxSeats }, { "default", WorldCode.DefaultSeats } } },
        { "difficulties", new RubyArray(Enumerable.Range(WorldDifficulty.Min, WorldDifficulty.Max - WorldDifficulty.Min + 1).Select(value => (RubyValue)new RubyArray([value, WorldDifficulty.Names[value - WorldDifficulty.Min]]))) },
        { "difficulty", WorldDifficulty.Default },
        { "formations", new RubyArray(RaidSquad.Formations.Select(size => (RubyValue)new RubyArray([size, FormationName(size)]))) },
        { "fronts", new RubyArray(RaidSquad.Fronts.Select(size => (RubyValue)size)) },
        { "squad", SquadTopics.ValueOf(RaidSquad.Default)! },
    };

    /// <summary>
    /// Names a formation size for the forms and the details.
    /// </summary>
    /// <param name="size">The size.</param>
    /// <returns><see cref="RaidSquad.OriginalFormationName"/>, or the size as text.</returns>
    internal static string FormationName(int size) =>
        size == RaidSquad.OriginalFormation ? RaidSquad.OriginalFormationName : size.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Answers <see cref="Code"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The code and its seats, <see langword="null"/> for a text that is no world code.</returns>
    private static RubyHash? CodeOf(RubyHash request)
    {
        if (WorldCode.Parse(request["code"].AsText()) is not { } code)
        {
            return null;
        }

        RubyValue seats = request["seats"];
        if (!seats.IsNil && seats.AsInt() is var wanted and >= WorldCode.MinSeats and <= WorldCode.MaxSeats)
        {
            code = code with { Seats = wanted };
        }

        return new RubyHash { { "code", code.ToText() }, { "seats", code.Seats } };
    }
}
