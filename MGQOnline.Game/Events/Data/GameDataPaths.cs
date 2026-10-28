//----------------------------------------------------------------
//  GameDataPaths.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Added the map a transfer names inside the folder of the map that runs it
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The paths of the game's data files, as its DataManager names them.
/// </summary>
public static class GameDataPaths
{
    /// <summary>
    /// The maps each folder of maps holds at most: map 1234 is Map234 of the first Data/Map folder.
    /// </summary>
    public const int MapsPerFolder = 1000;

    /// <summary>The common events.</summary>
    public const string CommonEvents = "Data/CommonEvents.rvdata2";

    /// <summary>The troops.</summary>
    public const string Troops = "Data/Troops.rvdata2";

    /// <summary>The system data: the names of the switches and variables.</summary>
    public const string System = "Data/System.rvdata2";

    /// <summary>The actors.</summary>
    public const string Actors = "Data/Actors.rvdata2";

    /// <summary>
    /// Finds the folder of maps a map id lies in, as the game's <c>DataManager.over_map_dir</c>.
    /// </summary>
    /// <param name="folder">The folder's number: 0 for Data itself, 1 for Data/Map, 2 for Data/Map2.</param>
    /// <returns>The folder that holds its MapNNN and MapInfos files.</returns>
    public static string MapFolder(int folder) => folder switch
    {
        0 => "Data",
        1 => "Data/Map/Data",
        _ => FormattableString.Invariant($"Data/Map{folder}/Data"),
    };

    /// <summary>
    /// Finds a map's file, as the game's <c>DataManager.map_file_name</c>.
    /// </summary>
    /// <param name="mapId">The map.</param>
    /// <returns>Its path, such as "Data/Map/Data/Map848.rvdata2" for map 1848.</returns>
    public static string Map(int mapId) =>
        FormattableString.Invariant($"{MapFolder(mapId / MapsPerFolder)}/Map{mapId % MapsPerFolder:000}.rvdata2");

    /// <summary>
    /// Finds the map a Transfer Player command names by number, as the game's <c>command_201</c>
    /// resolves it for a map event: inside the folder of the event's map.
    /// </summary>
    /// <param name="number">The map number the command holds.</param>
    /// <param name="runningMap">The map whose event runs the command, also through a common event it calls; 0 for a list no map event runs.</param>
    /// <returns>The map's id, such as 1005 for number 5 run on map 1848.</returns>
    public static int TransferMap(int number, int runningMap) =>
        number + runningMap / MapsPerFolder * MapsPerFolder;

    /// <summary>
    /// Finds the map list of a folder of maps.
    /// </summary>
    /// <param name="folder">The folder's number, see <see cref="MapFolder"/>.</param>
    /// <returns>Its MapInfos file.</returns>
    public static string MapInfos(int folder) => MapFolder(folder) + "/MapInfos.rvdata2";
}
