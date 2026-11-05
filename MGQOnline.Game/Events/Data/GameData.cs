//----------------------------------------------------------------
//  GameData.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the game's extended choices as choices by the variable of their answers
//      Paulinchen  2026-10-23: Read each file once when threads ask for it together
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The game's event data, read from its data files as the rules need it: the maps' events, the
/// common events, the troops' battle events, the switch and variable names and the map list.
/// </summary>
/// <remarks>
/// Each file is read once on first use and kept, the maps excepted, which a caller keeps as it
/// needs them; a game of 1,843 maps would not fit the game's 32-bit process at once. A file another
/// thread reads meanwhile is waited for, never read twice.
/// </remarks>
public sealed class GameData
{
    /// <summary>
    /// Where the files come from.
    /// </summary>
    private readonly IGameDataFiles _files;

    /// <summary>
    /// Reads the files' objects into the event types.
    /// </summary>
    private readonly GameDataPruner _pruner;

    /// <summary>
    /// The switch and variable names.
    /// </summary>
    private readonly ReadOnce<GameSystemNames> _system;

    /// <summary>
    /// The common events by id.
    /// </summary>
    private readonly ReadOnce<CommonEvent?[]> _commonEvents;

    /// <summary>
    /// The troops by id.
    /// </summary>
    private readonly ReadOnce<Troop?[]> _troops;

    /// <summary>
    /// Every map the map lists name.
    /// </summary>
    private readonly ReadOnce<MapInfo[]> _maps;

    /// <summary>
    /// How many actors the game's list holds.
    /// </summary>
    private readonly ReadOnce<int> _actorCount;

    /// <summary>
    /// Initializes the data of some files, each read on first use.
    /// </summary>
    /// <param name="files">Where the files come from.</param>
    /// <param name="exChoiceResult">The variable the game's extended choices write their answer into, <see langword="null"/> while unknown, which reads them as talk.</param>
    public GameData(IGameDataFiles files, long? exChoiceResult = null)
    {
        _files = files;
        _pruner = exChoiceResult is null ? GameDataPruner.Instance : new GameDataPruner(exChoiceResult);
        _system = new(ReadSystem);
        _commonEvents = new(() => ReadList<CommonEvent>(GameDataPaths.CommonEvents));
        _troops = new(() => ReadList<Troop>(GameDataPaths.Troops));
        _maps = new(ReadMapInfos);
        _actorCount = new(() => Read(GameDataPaths.Actors) is RubyArray actors ? actors.Count : 0);
    }

    /// <summary>
    /// Gets the switch and variable names.
    /// </summary>
    public GameSystemNames System => _system.Value;

    /// <summary>
    /// Gets the common events by id, <see langword="null"/> where the game has none.
    /// </summary>
    public IReadOnlyList<CommonEvent?> CommonEvents => _commonEvents.Value;

    /// <summary>
    /// Gets the troops by id, <see langword="null"/> where the game has none.
    /// </summary>
    public IReadOnlyList<Troop?> Troops => _troops.Value;

    /// <summary>
    /// Gets every map the map lists of Data and its Data/Map folders name, by id.
    /// </summary>
    public IReadOnlyList<MapInfo> Maps => _maps.Value;

    /// <summary>
    /// Gets how many entries the game's actor list holds, its first empty one included, which is
    /// how many affection variables the game keeps.
    /// </summary>
    public int ActorCount => _actorCount.Value;

    /// <summary>
    /// Opens the data of a game folder, see <see cref="GameFolderFiles"/>.
    /// </summary>
    /// <param name="folder">The folder.</param>
    /// <returns>Its data.</returns>
    public static GameData OfFolder(string folder) => new(new GameFolderFiles(folder));

    /// <summary>
    /// Gets a common event.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <returns>The common event, <see langword="null"/> for none.</returns>
    public CommonEvent? CommonEvent(long id) => id > 0 && id < CommonEvents.Count ? CommonEvents[(int)id] : null;

    /// <summary>
    /// Reads a map's events.
    /// </summary>
    /// <param name="id">The map.</param>
    /// <returns>Its events, <see langword="null"/> for a map without a file.</returns>
    /// <exception cref="InvalidDataException">The file is damaged.</exception>
    /// <exception cref="RubyValueException">The file is no Marshal data.</exception>
    public GameMap? ReadMap(int id)
    {
        string path = GameDataPaths.Map(id);
        if (id <= 0 || !_files.Exists(path))
        {
            return null;
        }

        var events = new SortedDictionary<int, MapEvent>();
        if (Read(path) is RubyObject map && map["events"] is RubyHash hash)
        {
            foreach ((_, RubyValue value) in hash)
            {
                MapEvent mapEvent = GameDataPruner.Content<MapEvent>(value) ?? throw new InvalidDataException($"Map {id} holds {value.KindName} among its events.");
                events[mapEvent.Id] = mapEvent;
            }
        }

        return new GameMap(id, events);
    }

    /// <summary>
    /// Reads a data file through the pruner.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>Its value, nil for a file that is not there.</returns>
    private RubyValue Read(string path) => _files.Exists(path) ? RubyMarshal.Read(_files.Read(path), _pruner) : RubyNil.Value;

    /// <summary>
    /// Reads a data file that lists objects by id, its first entry empty.
    /// </summary>
    /// <typeparam name="T">The objects.</typeparam>
    /// <param name="path">The file.</param>
    /// <returns>The objects by id.</returns>
    private T?[] ReadList<T>(string path)
        where T : class =>
        Read(path) is RubyArray list ? list.Select(GameDataPruner.Content<T>).ToArray() : [];

    /// <summary>
    /// Reads the switch and variable names.
    /// </summary>
    /// <returns>The names.</returns>
    private GameSystemNames ReadSystem()
    {
        RubyObject? system = Read(GameDataPaths.System) as RubyObject;
        return new GameSystemNames(NamesOf(system?["switches"]), NamesOf(system?["variables"]));
    }

    /// <summary>
    /// Reads a list of names.
    /// </summary>
    /// <param name="value">The Array, nil for none.</param>
    /// <returns>The names, empty where the game has none.</returns>
    private static string[] NamesOf(RubyValue? value) =>
        value is RubyArray names ? names.Select(GameDataPruner.TextOf).ToArray() : [];

    /// <summary>
    /// Reads the map lists of Data and of each Data/Map folder after it, as the game's MapInfos does.
    /// </summary>
    /// <returns>The maps, by id.</returns>
    private MapInfo[] ReadMapInfos()
    {
        var maps = new List<MapInfo>();
        for (int folder = 0; folder == 0 || _files.Exists(GameDataPaths.MapInfos(folder)); folder++)
        {
            if (Read(GameDataPaths.MapInfos(folder)) is not RubyHash infos)
            {
                continue;
            }

            foreach (KeyValuePair<RubyValue, RubyValue> pair in infos)
            {
                int number = GameDataPruner.Int(pair.Key);
                MapInfo info = GameDataPruner.Content<MapInfo>(pair.Value) ?? new MapInfo(0, string.Empty, 0);
                int offset = folder * GameDataPaths.MapsPerFolder;
                maps.Add(info with { Id = offset + number, ParentId = info.ParentId > 0 ? offset + info.ParentId : 0 });
            }
        }

        return [.. maps.OrderBy(map => map.Id)];
    }
}
