//----------------------------------------------------------------
//  OverviewState.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Battles.Live;

namespace MGQOnline.Game.Overview;

/// <summary>
/// What the player's game tells the others of the player for the World overview: the highest
/// level of the formation, in a Raid World of the Frontline too, the place in the story, read
/// every <see cref="ReadFrames"/> while in a world, and where the player is.
/// </summary>
public sealed class OverviewState
{
    /// <summary>
    /// The frames between two readings of the levels and the story.
    /// </summary>
    public const int ReadFrames = 180;

    /// <summary>
    /// Frames until the next reading.
    /// </summary>
    private int frames;

    /// <summary>
    /// Gets the formation's highest level as last read, <see langword="null"/> before the first reading.
    /// </summary>
    public int? Level { get; private set; }

    /// <summary>
    /// Gets the place in the story as last read, see <see cref="OverviewText.StoryCode"/>;
    /// <see langword="null"/> before the first reading.
    /// </summary>
    public string? Story { get; private set; }

    /// <summary>
    /// Gets the Frontline's highest level as last read, <see langword="null"/> before the first
    /// reading and outside a Raid World.
    /// </summary>
    public int? Front { get; private set; }

    /// <summary>
    /// Gets where the player is as last told, empty on a map the game names nowhere.
    /// </summary>
    public string Place { get; private set; } = string.Empty;

    /// <summary>
    /// Counts one frame of the bridge's drain, forgetting what was read outside a world so the next
    /// world reads afresh at once.
    /// </summary>
    /// <param name="inWorld">Whether a world is open.</param>
    /// <returns>Whether the game reads the levels and the story now, see <see cref="Take"/>.</returns>
    public bool Step(bool inWorld)
    {
        if (!inWorld)
        {
            Forget();
            return false;
        }

        frames--;
        if (frames > 0)
        {
            return false;
        }

        frames = ReadFrames;
        return true;
    }

    /// <summary>
    /// Keeps what the game read; during a co-op battle the levels read before it stay.
    /// </summary>
    /// <remarks>
    /// The battle's party and its level sync stand in for the player's own characters then.
    /// </remarks>
    /// <param name="reading">What the game read.</param>
    /// <returns>The log's line when anything changed, <see langword="null"/> otherwise.</returns>
    public string? Take(OverviewReading reading)
    {
        int level = reading.Battle ? Level ?? 0 : reading.Level;
        int? front = reading.Front is null ? null : reading.Battle ? Front ?? 0 : reading.Front;
        string? line = (level, reading.Story, front) == (Level, Story, Front) ? null
            : $"told the others: level {Inspect(Level)} -> {level}, story {Inspect(Story)} -> {RubyText.InspectString(reading.Story)}"
              + (front is { } told ? $", Frontline level {Inspect(Front)} -> {told}" : string.Empty);
        Level = level;
        Story = reading.Story;
        Front = front;
        return line;
    }

    /// <summary>
    /// Forgets what was read, so the next world reads afresh at once instead of telling the last one's.
    /// </summary>
    public void Forget()
    {
        Level = null;
        Story = null;
        Front = null;
        frames = 0;
    }

    /// <summary>
    /// Keeps where the player is and tells the fields the overview adds to the state the player's
    /// game tells the others.
    /// </summary>
    /// <param name="place">Where the player is, the map's name as the game shows it.</param>
    /// <param name="raid">Whether the world is a Raid World, which tells the Frontline's level too.</param>
    /// <returns>The fields.</returns>
    public OverviewFields Fields(string place, bool raid)
    {
        Place = place ?? string.Empty;
        return new OverviewFields(Place, Level ?? 0, Story ?? string.Empty, raid ? Front ?? 0 : null);
    }

    /// <summary>
    /// Writes a level read as Ruby's inspect writes it.
    /// </summary>
    /// <param name="level">The level.</param>
    /// <returns>Its digits, "nil" for none.</returns>
    private static string Inspect(int? level) => level?.ToString(System.Globalization.CultureInfo.InvariantCulture) ?? "nil";

    /// <summary>
    /// Writes a place in the story read as Ruby's inspect writes it.
    /// </summary>
    /// <param name="story">The place.</param>
    /// <returns>It in quotes, "nil" for none.</returns>
    private static string Inspect(string? story) => story is null ? "nil" : RubyText.InspectString(story);
}
