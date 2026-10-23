//----------------------------------------------------------------
//  WorldTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts ask the rules of a world: its seats, difficulties,
/// squad settings and the seats its code tells.
/// </summary>
internal static class WorldTopics
{
    /// <summary>
    /// Hands out the limits and defaults of a world's settings: nothing in; <c>seats</c> (<c>min</c>,
    /// <c>max</c>, <c>default</c>), <c>difficulties</c> ([value, name] each), <c>difficulty</c> (the
    /// default), <c>formations</c> ([size, name] each), <c>fronts</c> and <c>squad</c> (the default
    /// squad settings, as <see cref="SquadRead"/> answers them) out.
    /// </summary>
    public const string Rules = "world.rules";

    /// <summary>
    /// Reads squad settings from their text, see <see cref="RaidSquad"/>: the text in; <c>luka</c>,
    /// <c>formation</c>, <c>front</c> and <c>raid_front</c> out, nil for a text of no valid settings.
    /// </summary>
    public const string SquadRead = "squad.read";

    /// <summary>
    /// Writes squad settings as their text: the settings as <see cref="SquadRead"/> answers them in;
    /// the text out, nil for settings out of range.
    /// </summary>
    public const string SquadWrite = "squad.write";

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
        context.Register(SquadRead, (_, request) => SquadOf(request.AsText()));
        context.Register(SquadWrite, (_, request) => SquadText(request.AsHash()));
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
        { "squad", SquadOf(RaidSquad.Default)! },
    };

    /// <summary>
    /// Names a formation size for the forms and the details.
    /// </summary>
    /// <param name="size">The size.</param>
    /// <returns><see cref="RaidSquad.OriginalFormationName"/>, or the size as text.</returns>
    private static string FormationName(int size) =>
        size == RaidSquad.OriginalFormation ? RaidSquad.OriginalFormationName : size.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Answers <see cref="SquadRead"/>.
    /// </summary>
    /// <param name="text">The settings' text.</param>
    /// <returns>The settings, <see langword="null"/> for a text of no valid settings.</returns>
    private static RubyHash? SquadOf(string text) =>
        RaidSquad.TryParse(text, out bool luka, out int formation, out int front, out int raidFront)
            ? new RubyHash { { "luka", luka }, { "formation", formation }, { "front", front }, { "raid_front", raidFront } }
            : null;

    /// <summary>
    /// Answers <see cref="SquadWrite"/>.
    /// </summary>
    /// <param name="squad">The settings.</param>
    /// <returns>Their text, <see langword="null"/> for settings out of range.</returns>
    private static RubyValue? SquadText(RubyHash squad)
    {
        string text = RaidSquad.TextOf(squad["luka"].AsBool(), squad["formation"].AsInt(), squad["front"].AsInt(), squad["raid_front"].AsInt());
        return RaidSquad.IsValid(text) ? text : null;
    }

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
