//----------------------------------------------------------------
//  GameDataTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Checked the numbers and script kinds of the commands read
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the reader of the game's event data: where the game keeps its maps, its archive, and the
/// real data of the game folder BATTLE_GAME_DIR names.
/// </summary>
public sealed class GameDataTests
{
    /// <summary>
    /// Asserts that maps from 1000 on lie in the Data/Map folders, as the game's DataManager finds them.
    /// </summary>
    [Fact]
    public void MapPaths_FollowTheFoldersOfAThousandMaps()
    {
        Assert.Equal("Data/Map005.rvdata2", GameDataPaths.Map(5));
        Assert.Equal("Data/Map/Data/Map848.rvdata2", GameDataPaths.Map(1848));
        Assert.Equal("Data/Map2/Data/Map001.rvdata2", GameDataPaths.Map(2001));
        Assert.Equal("Data/Map/Data/MapInfos.rvdata2", GameDataPaths.MapInfos(1));
    }

    /// <summary>
    /// Asserts that a game folder reads a file from its archive before a loose one, and a file only
    /// loose from the disk.
    /// </summary>
    [Fact]
    public void GameFolderFiles_ReadTheArchiveFirst()
    {
        string folder = Directory.CreateTempSubdirectory("mgq-archive-").FullName;
        try
        {
            Directory.CreateDirectory(Path.Combine(folder, "Data"));
            File.WriteAllText(Path.Combine(folder, "Data", "System.rvdata2"), "loose");
            File.WriteAllText(Path.Combine(folder, "Data", "Loose.rvdata2"), "only loose");
            File.WriteAllBytes(Path.Combine(folder, GameFolderFiles.ArchiveName), Archive(("Data\\System.rvdata2", "packed system, 22 bytes"u8.ToArray())));

            var files = new GameFolderFiles(folder);

            Assert.Equal("packed system, 22 bytes", Encoding.UTF8.GetString(files.Read("Data/System.rvdata2")));
            Assert.Equal("only loose", Encoding.UTF8.GetString(files.Read("Data/Loose.rvdata2")));
            Assert.False(files.Exists("Data/Missing.rvdata2"));
        }
        finally
        {
            Directory.Delete(folder, recursive: true);
        }
    }

    /// <summary>
    /// Asserts that the game folder's maps, from both folders of maps, its common events, troops,
    /// names and actors read.
    /// </summary>
    [Fact]
    public void GameData_ReadsTheGameFolder()
    {
        GameData data = GameFolder.DataOrSkip();

        MapInfo first = data.Maps[0];
        GameMap? map = data.ReadMap(first.Id);

        Assert.NotNull(map);
        Assert.NotEmpty(map.Events);
        Assert.All(map.Events.Values, mapEvent => Assert.NotEmpty(mapEvent.Pages));
        Assert.Contains(data.CommonEvents, common => common is { List.Count: > 1 });
        Assert.Contains(data.Troops, troop => troop is { Pages.Count: > 0 });
        Assert.True(data.System.Switches.Count > 1000 && data.System.Variables.Count > 1000);
        Assert.True(data.ActorCount > 1);
        if (data.Maps.FirstOrDefault(info => info.Id > GameDataPaths.MapsPerFolder) is { } later)
        {
            Assert.NotNull(data.ReadMap(later.Id));
        }
    }

    /// <summary>
    /// Asserts that the reader keeps the parameters the rules read and leaves out the dialogue's.
    /// </summary>
    [Fact]
    public void GameData_KeepsOnlyTheParametersTheRulesRead()
    {
        GameData data = GameFolder.DataOrSkip();

        List<EventCommand> commands = data.CommonEvents.Where(common => common is not null).SelectMany(common => common!.List).ToList();

        Assert.All(commands.Where(command => command.Code == 401).Take(100), command => Assert.Empty(command.Numbers));
        Assert.Contains(commands, command => command.Code == EventCodes.Branch && command.Numbers.Length >= 3);
        Assert.Contains(commands, command => command.Code == EventCodes.Script && command.TextKind == TextKind.Talk);
    }

    /// <summary>
    /// Packs files into an RGSS3 archive as the game's tools do.
    /// </summary>
    /// <param name="files">Each file's path and bytes.</param>
    /// <returns>The archive.</returns>
    private static byte[] Archive(params (string Path, byte[] Bytes)[] files)
    {
        const uint headerKey = 0x1234567;
        uint key = unchecked((headerKey * 9) + 3);
        using var stream = new MemoryStream();
        using var writer = new BinaryWriter(stream);
        writer.Write("RGSSAD\0"u8);
        writer.Write((byte)3);
        writer.Write(headerKey);
        int tableSize = files.Sum(file => 16 + Encoding.UTF8.GetByteCount(file.Path)) + 4;
        long offset = stream.Position + tableSize;
        foreach ((string path, byte[] bytes) in files)
        {
            byte[] name = Encoding.UTF8.GetBytes(path);
            writer.Write((uint)offset ^ key);
            writer.Write((uint)bytes.Length ^ key);
            writer.Write(0xBEEFu ^ key);
            writer.Write((uint)name.Length ^ key);
            writer.Write(name.Select((value, index) => (byte)(value ^ (byte)(key >> (8 * (index % 4))))).ToArray());
            offset += bytes.Length;
        }

        writer.Write(key);
        foreach ((_, byte[] bytes) in files)
        {
            writer.Write(Encrypted(bytes, 0xBEEF));
        }

        return stream.ToArray();
    }

    /// <summary>
    /// Ciphers a file's bytes as the archive keeps them.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <param name="key">The file's key.</param>
    /// <returns>The ciphered bytes.</returns>
    private static byte[] Encrypted(byte[] bytes, uint key)
    {
        byte[] data = (byte[])bytes.Clone();
        int whole = data.Length & ~3;
        for (int index = 0; index < whole; index += 4)
        {
            Span<byte> word = data.AsSpan(index, 4);
            BinaryPrimitives.WriteUInt32LittleEndian(word, BinaryPrimitives.ReadUInt32LittleEndian(word) ^ key);
            key = unchecked((key * 7) + 3);
        }

        for (int index = whole; index < data.Length; index++)
        {
            data[index] ^= (byte)(key >> (8 * (index - whole)));
        }

        return data;
    }
}
