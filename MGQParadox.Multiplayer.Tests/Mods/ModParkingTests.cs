//----------------------------------------------------------------
//  ModParkingTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Covered links to another volume, read-only and changed parked files, conflicts after a recover and an unreadable journal
//                            - Covered read-only scripts through a park and a restore and the answer of a failed description
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers parking the mods a world does not name: the moves out of Patch and back, the journal that
/// survives a crash at any point, the conflicts folder, the restore as a game starts, and the lock
/// that keeps a second game of the same folder out.
/// </summary>
public sealed class ModParkingTests : IDisposable
{
    /// <summary>
    /// The world the tests park mods for.
    /// </summary>
    private const string World = "0123456789abcdef0123456789abcdef";

    /// <summary>
    /// Another world.
    /// </summary>
    private const string OtherWorld = "fedcba9876543210fedcba9876543210";

    /// <summary>
    /// A game folder of the test's own.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The junctions the test made, which the recursive delete of its folder cannot remove.
    /// </summary>
    private readonly List<string> _junctions = [];

    /// <summary>
    /// Asserts that parking moves the scripts out of Patch with their paths kept, leaves the data
    /// folders, and lists every one in the journal and for the game script.
    /// </summary>
    [Fact]
    public void Park_MovesTheScriptsAndListsThem()
    {
        var invasions = WriteMod("Patch/Invasions.rb", "# Invasions\r\n");
        WriteMod("Patch/Extra/Other.rb", "# Other\n");
        WriteMod("Patch/Luka_Replacer/Cache/hero.txt", "Kazuya");
        using var parking = Parking();

        Assert.Equal(2, parking.Park(["Patch/Invasions.rb", "Patch\\Extra\\Other.rb"], World));

        Assert.False(File.Exists(GamePath("Patch/Invasions.rb")));
        Assert.Equal("# Invasions\r\n", File.ReadAllText(GamePath("Parked mods/Patch/Invasions.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/Extra/Other.rb")));
        Assert.True(File.Exists(GamePath("Patch/Luka_Replacer/Cache/hero.txt")));
        Assert.Equal(
            [$"world\t{World}", "after\tnone", $"file\tPatch/Invasions.rb\t{invasions}\t1", $"file\tPatch/Extra/Other.rb\t{ModHash.Of("Other.rb", "# Other\n"u8)}\t1"],
            File.ReadAllLines(parking.JournalPath));
        Assert.False(File.Exists(parking.JournalPath + ".tmp"));

        var described = Message.Decode(parking.Describe());
        Assert.Equal((World, "2", "0"), (described["world"], described["files"], described["conflicts"]));
        Assert.Equal("Patch/Invasions.rb\nPatch/Extra/Other.rb", described.Team);
    }

    /// <summary>
    /// Asserts that the mod loader, this mod and every script in its folder, Mod Config Remake under
    /// any spelling, anything but a script and anything outside Patch are never parked.
    /// </summary>
    [Fact]
    public void Park_NeverMovesWhatMustStay()
    {
        string[] staying = ["Patch/Patch.rb", "Patch/Multiplayer.rb", "Patch/0_ModConfigRemake.rb", "Patch/Sub/0 Mod-Config_remake.RB", "Patch/Multiplayer/Multiplayer.rb", "Patch/Multiplayer/Helper.rb", "Patch/multiplayer/Sub/Other.rb", "Patch/Luka_Replacer/data.txt", "Save/Old.rb", "Game.rb"];

        foreach (var path in staying)
        {
            WriteMod(path, "# stays\n");
        }

        using var parking = Parking();

        Assert.Equal(0, parking.Park([.. staying, "../Outside.rb", "C:/Windows/win.rb", "Patch/Missing.rb", string.Empty], World));
        Assert.All(staying, path => Assert.True(File.Exists(GamePath(path)), path));
        Assert.False(File.Exists(parking.JournalPath));
        Assert.Empty(parking.Describe());
    }

    /// <summary>
    /// Asserts that the scripts a world may park are listed with their names in any script, those in
    /// subfolders too, without this mod's folder, the never-parked scripts, other files and what
    /// starts with a dot, followed by the parked ones; and that each listed path parks.
    /// </summary>
    [Fact]
    public void Scripts_ListsWhatAWorldMayPark()
    {
        WriteMod("Patch/Invasions.rb", "# Invasions\n");
        WriteMod("Patch/Ünïcode 模组/Main.RB", "# Unicode\n");
        WriteMod("Patch/Extra/Deep/Other.rb", "# Other\n");
        WriteMod("Patch/B.rb", "# B\n");
        string[] unlisted = ["Patch/Patch.rb", "Patch/0_ModConfigRemake.rb", "Patch/Multiplayer.rb", "Patch/Multiplayer/Helper.rb", "Patch/Multiplayer/Scripts/core.rbx", "Patch/Extra/readme.txt", "Patch/.git/hook.rb", "Patch/.Hidden.rb", "Save/Old.rb"];

        foreach (var path in unlisted)
        {
            WriteMod(path, "# unlisted\n");
        }

        using var parking = Parking();
        Assert.Equal(
            "patch\tPatch/B.rb\npatch\tPatch/Extra/Deep/Other.rb\npatch\tPatch/Invasions.rb\npatch\tPatch/Ünïcode 模组/Main.RB",
            parking.Scripts());

        Assert.Equal(2, parking.Park(["Patch/B.rb", "Patch/Ünïcode 模组/Main.RB"], World));

        Assert.Equal(
            "patch\tPatch/Extra/Deep/Other.rb\npatch\tPatch/Invasions.rb\nparked\tPatch/B.rb\nparked\tPatch/Ünïcode 模组/Main.RB",
            parking.Scripts());
        Assert.True(File.Exists(GamePath("Parked mods/Patch/Ünïcode 模组/Main.RB")));
    }

    /// <summary>
    /// Asserts that the scripts behind a junction in Patch are listed and parked like any other, as
    /// the game's Ruby loads them, that a junction leading back up is listed once, and that a
    /// junction to a missing folder holds none.
    /// </summary>
    [Fact]
    public void Scripts_FollowsJunctions()
    {
        WriteMod("Dev/SomeMod/Main.rb", "# Main\n");
        WriteMod("Patch/A.rb", "# A\n");
        Junction("Patch/SomeMod", "Dev/SomeMod");
        Junction("Dev/SomeMod/Loop", "Dev/SomeMod");
        Directory.CreateDirectory(GamePath("Dev/Gone"));
        Junction("Patch/Gone", "Dev/Gone");
        Directory.Delete(GamePath("Dev/Gone"));
        using var parking = Parking();

        Assert.Equal("patch\tPatch/A.rb\npatch\tPatch/SomeMod/Main.rb", parking.Scripts());

        Assert.Equal(1, parking.Park(["Patch/SomeMod/Main.rb"], World));
        Assert.False(File.Exists(GamePath("Dev/SomeMod/Main.rb")));
        Assert.Equal("patch\tPatch/A.rb\nparked\tPatch/SomeMod/Main.rb", parking.Scripts());

        Assert.Equal(1, parking.Restore(false));
        Assert.True(File.Exists(GamePath("Dev/SomeMod/Main.rb")));
    }

    /// <summary>
    /// Asserts that the scripts behind a link to another volume are listed first as elsewhere and
    /// never parked, while a link inside it that leads back to the game's volume parks as usual.
    /// </summary>
    [Fact]
    public void Scripts_BehindALinkToAnotherVolume_AreListedElsewhereAndNeverParked()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Dev/Far/Main.rb", "# Main\n");
        WriteMod("Dev/Far/Sub/Deep.rb", "# Deep\n");
        WriteMod("Dev/Near/Back.rb", "# Back\n");
        Junction("Patch/Far", "Dev/Far");
        Junction("Dev/Far/Near", "Dev/Near");
        var far = Path.Combine("Dev", "Far");
        using var parking = new ModParking(_game.Path)
        {
            InOptionsDump = () => false,
            IsElsewhere = target => Path.TrimEndingDirectorySeparator(target).EndsWith(far, StringComparison.OrdinalIgnoreCase),
        };

        Assert.Equal(
            "elsewhere\tPatch/Far/Main.rb\nelsewhere\tPatch/Far/Sub/Deep.rb\npatch\tPatch/A.rb\npatch\tPatch/Far/Near/Back.rb",
            parking.Scripts());

        Assert.Equal(1, parking.Park(["Patch/Far/Main.rb", "Patch/Far/Near/Back.rb"], World));
        Assert.True(File.Exists(GamePath("Dev/Far/Main.rb")));
        Assert.False(File.Exists(GamePath("Dev/Near/Back.rb")));
        Assert.Equal("Patch/Far/Near/Back.rb", Message.Decode(parking.Describe()).Team);
        Assert.Equal(1, parking.Restore(false));
    }

    /// <summary>
    /// Asserts that a link's target counts as elsewhere by its root alone, ignoring case, with a
    /// volume named by its id or a share as another.
    /// </summary>
    [Fact]
    public void OnOtherVolume_ComparesTheRoots()
    {
        Assert.False(ModParking.OnOtherVolume(@"c:\Dev\Mod", @"C:\Games\MGQ Paradox"));
        Assert.True(ModParking.OnOtherVolume(@"D:\Dev\Mod", @"C:\Games\MGQ Paradox"));
        Assert.True(ModParking.OnOtherVolume(@"\\?\Volume{01234567-89ab-cdef-0123-456789abcdef}\Mod", @"C:\Games\MGQ Paradox"));
        Assert.True(ModParking.OnOtherVolume(@"\\server\share\Mod", @"C:\Games\MGQ Paradox"));
    }

    /// <summary>
    /// Asserts that a read-only parked copy the same as the file in Patch is still dropped and leaves
    /// no journal entry behind, so later parks are not refused.
    /// </summary>
    [Fact]
    public void Restore_AReadOnlyParkedCopy_IsDropped()
    {
        WriteMod("Patch/A.rb", "# A\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb"], World);
        WriteMod("Patch/A.rb", "# A\n");
        File.SetAttributes(GamePath("Parked mods/Patch/A.rb"), FileAttributes.ReadOnly);

        Assert.Equal(1, parking.Restore(false));

        Assert.False(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        Assert.False(File.Exists(parking.JournalPath));
        Assert.Equal(1, parking.Park(["Patch/A.rb"], World));
    }

    /// <summary>
    /// Asserts that a read-only script stays read-only through a park and a restore, also when it goes
    /// to the conflicts folder.
    /// </summary>
    [Fact]
    public void ParkAndRestore_KeepAReadOnlyScriptReadOnly()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/B.rb", "# B 1.0\n");
        File.SetAttributes(GamePath("Patch/A.rb"), FileAttributes.ReadOnly);
        File.SetAttributes(GamePath("Patch/B.rb"), FileAttributes.ReadOnly);
        using var parking = new ModParking(_game.Path) { InOptionsDump = () => false, Clock = () => new DateTime(2026, 10, 10, 9, 45, 0) };

        Assert.Equal(2, parking.Park(["Patch/A.rb", "Patch/B.rb"], World));
        Assert.True(File.GetAttributes(GamePath("Parked mods/Patch/A.rb")).HasFlag(FileAttributes.ReadOnly));
        WriteMod("Patch/B.rb", "# B 2.0\n");

        Assert.Equal(2, parking.Restore(false));

        Assert.True(File.GetAttributes(GamePath("Patch/A.rb")).HasFlag(FileAttributes.ReadOnly));
        Assert.False(File.GetAttributes(GamePath("Patch/B.rb")).HasFlag(FileAttributes.ReadOnly));
        Assert.True(File.GetAttributes(GamePath("Parked mods/Conflicts/2026-10-10 09-45-00/Patch/B.rb")).HasFlag(FileAttributes.ReadOnly));
    }

    /// <summary>
    /// Asserts that a failed description answers the error header alone, with the exception's message
    /// on one line, or its type when it has none, never what reads as nothing parked.
    /// </summary>
    [Fact]
    public void DescribeFailure_AnswersTheErrorHeaderAlone()
    {
        var typed = Message.Decode(ModParking.DescribeFailure(new InvalidOperationException(string.Empty)));
        var told = Message.Decode(ModParking.DescribeFailure(new InvalidOperationException("broken\nhere")));

        Assert.Equal(("InvalidOperationException", string.Empty, string.Empty), (typed[ModParking.DescribeError], typed["files"], typed.Team));
        Assert.Equal("broken here", told[ModParking.DescribeError]);
    }

    /// <summary>
    /// Asserts that a parked file that is no longer the one parked goes to the conflicts folder and
    /// never into Patch, and counts as a conflict.
    /// </summary>
    [Fact]
    public void Restore_AParkedFileThatChanged_GoesToConflicts()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/B.rb", "# B\n");
        using var parking = new ModParking(_game.Path) { InOptionsDump = () => false, Clock = () => new DateTime(2026, 10, 10, 9, 30, 0) };
        parking.Park(["Patch/A.rb", "Patch/B.rb"], World);
        WriteMod("Parked mods/Patch/A.rb", "# Something else\n");

        Assert.Equal(2, parking.Restore(false));

        Assert.False(File.Exists(GamePath("Patch/A.rb")));
        Assert.Equal("# Something else\n", File.ReadAllText(GamePath("Parked mods/Conflicts/2026-10-10 09-30-00/Patch/A.rb")));
        Assert.Equal("# B\n", File.ReadAllText(GamePath("Patch/B.rb")));
        Assert.Equal(1, parking.LastConflicts);
        Assert.False(File.Exists(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that the conflicts of the restore a recover makes stay in the description once nothing
    /// is parked, without a world, so the game script can tell the player.
    /// </summary>
    [Fact]
    public void Describe_AfterARecoverWithConflicts_TellsThem()
    {
        WriteMod("Patch/A.rb", "# A 1.0\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb"], World);
        WriteMod("Patch/A.rb", "# A 2.0\n");

        Assert.Equal(1, parking.Recover(OtherWorld));

        var described = Message.Decode(parking.Describe());
        Assert.Equal((string.Empty, "0", "1", string.Empty), (described["world"], described["files"], described["conflicts"], described.Team));
    }

    /// <summary>
    /// Asserts that a journal that cannot be read is described by the error header alone, never as
    /// nothing parked, and described as usual once it can be read again.
    /// </summary>
    [Fact]
    public void Describe_AJournalThatCannotBeRead_SaysSo()
    {
        WriteMod("Patch/A.rb", "# A\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb"], World);

        using (new FileStream(parking.JournalPath, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            var failed = Message.Decode(parking.Describe());
            Assert.NotEmpty(failed[ModParking.DescribeError]);
            Assert.Equal((string.Empty, string.Empty, string.Empty), (failed["world"], failed["files"], failed.Team));
        }

        var described = Message.Decode(parking.Describe());
        Assert.Equal((World, "1", string.Empty), (described["world"], described["files"], described[ModParking.DescribeError]));
    }

    /// <summary>
    /// Asserts that a listing that fails answers only the failure line, never what reads as no
    /// script, so a world that turns other mods off is not entered with them on.
    /// </summary>
    [Fact]
    public void Scripts_AFailedListing_SaysSo()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/B.rb", "# B\n");
        using var parking = Parking();
        parking.Park(["Patch/B.rb"], World);

        using (new FileStream(parking.JournalPath, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            Assert.Equal(ModParking.ScriptsFailed, parking.Scripts());
        }

        Assert.Equal("patch\tPatch/A.rb\nparked\tPatch/B.rb", parking.Scripts());
    }

    /// <summary>
    /// Asserts that parking the same scripts for another world moves none of them and only names the
    /// new world in the journal, keeping its watchdog, as the game script does on entering a world
    /// while mods are parked for another one.
    /// </summary>
    [Fact]
    public void Park_TheSameScriptsForAnotherWorld_OnlyRenamesTheWorld()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/Sub/B.rb", "# B\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb", "Patch/Sub/B.rb"], World);
        var watch = parking.PrepareWatch(World, rejoin: true);
        var before = File.ReadAllLines(parking.JournalPath);
        var moved = File.GetLastWriteTimeUtc(GamePath("Parked mods/Patch/A.rb"));

        Assert.Equal(2, parking.Park(["Patch/Sub/B.rb", "Patch/A.rb"], OtherWorld));

        Assert.Equal(before.Select(line => line == $"world\t{World}" ? $"world\t{OtherWorld}" : line), File.ReadAllLines(parking.JournalPath));
        Assert.Contains($"watch\t{watch}", File.ReadAllLines(parking.JournalPath));
        Assert.Equal(moved, File.GetLastWriteTimeUtc(GamePath("Parked mods/Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/Sub/B.rb")));
        Assert.False(File.Exists(GamePath("Patch/A.rb")));
        Assert.False(Directory.Exists(GamePath("Parked mods/Conflicts")));
        Assert.Equal(OtherWorld, Message.Decode(parking.Describe())["world"]);
    }

    /// <summary>
    /// Asserts that a restore moves every parked mod back, removes the journal and the parking folder
    /// it leaves empty, and that nothing is parked afterwards.
    /// </summary>
    [Fact]
    public void Restore_MovesEveryModBack()
    {
        WriteMod("Patch/Invasions.rb", "# Invasions\n");
        WriteMod("Patch/Extra/Other.rb", "# Other\n");
        using var parking = Parking();
        parking.Park(["Patch/Invasions.rb", "Patch/Extra/Other.rb"], World);

        Assert.Equal(2, parking.Restore(true));

        Assert.Equal("# Invasions\n", File.ReadAllText(GamePath("Patch/Invasions.rb")));
        Assert.True(File.Exists(GamePath("Patch/Extra/Other.rb")));
        Assert.False(File.Exists(parking.JournalPath));
        Assert.False(Directory.Exists(GamePath("Parked mods")));
        Assert.Empty(parking.Describe());
        Assert.Equal(0, parking.Restore(false));
    }

    /// <summary>
    /// Asserts that a parked mod whose place in Patch another file took goes to the conflicts folder
    /// instead of overwriting it, while one whose place holds the same file only drops its copy.
    /// </summary>
    [Fact]
    public void Restore_NeverOverwrites()
    {
        WriteMod("Patch/Invasions.rb", "# Invasions 1.0\n");
        WriteMod("Patch/Same.rb", "# Same\n");
        using var parking = new ModParking(_game.Path) { InOptionsDump = () => false, Clock = () => new DateTime(2026, 10, 9, 20, 15, 30) };
        parking.Park(["Patch/Invasions.rb", "Patch/Same.rb"], World);
        WriteMod("Patch/Invasions.rb", "# Invasions 2.0\n");
        WriteMod("Patch/Same.rb", "# Same\r\n");

        Assert.Equal(2, parking.Restore(false));

        Assert.Equal("# Invasions 2.0\n", File.ReadAllText(GamePath("Patch/Invasions.rb")));
        Assert.Equal("# Invasions 1.0\n", File.ReadAllText(GamePath("Parked mods/Conflicts/2026-10-09 20-15-30/Patch/Invasions.rb")));
        Assert.Equal("# Same\r\n", File.ReadAllText(GamePath("Patch/Same.rb")));
        Assert.False(File.Exists(GamePath("Parked mods/Conflicts/2026-10-09 20-15-30/Patch/Same.rb")));
        Assert.Equal(1, parking.LastConflicts);
        Assert.False(File.Exists(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that parking for another world first brings back the mods it no longer turns off,
    /// keeps those it still does parked, and parks the new ones.
    /// </summary>
    [Fact]
    public void Park_ForAnotherWorld_BringsBackOnlyTheModsItAllows()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/B.rb", "# B\n");
        WriteMod("Patch/C.rb", "# C\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb", "Patch/B.rb"], World);

        Assert.Equal(2, parking.Park(["Patch/B.rb", "Patch/C.rb"], OtherWorld));

        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/B.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/C.rb")));
        Assert.False(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        var described = Message.Decode(parking.Describe());
        Assert.Equal((OtherWorld, "Patch/B.rb\nPatch/C.rb"), (described["world"], described.Team));
    }

    /// <summary>
    /// Asserts that a park whose earlier mods cannot all come back first moves nothing, answers 0 and
    /// keeps the earlier park as it was, so the game script sees it fail and keeps the mods it has.
    /// </summary>
    [Fact]
    public void Park_AnEarlierModThatCannotComeBack_MovesNothing()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/B.rb", "# B\n");
        WriteMod("Patch/C.rb", "# C\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb", "Patch/B.rb"], World);

        // An open file without delete sharing cannot be renamed, so A cannot come back.
        using (new FileStream(GamePath("Parked mods/Patch/A.rb"), FileMode.Open, FileAccess.Read, FileShare.Read))
        {
            Assert.Equal(0, parking.Park(["Patch/B.rb", "Patch/C.rb"], OtherWorld));
        }

        Assert.True(File.Exists(GamePath("Patch/C.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/B.rb")));
        var described = Message.Decode(parking.Describe());
        Assert.Equal((World, "Patch/A.rb\nPatch/B.rb"), (described["world"], described.Team));
    }

    /// <summary>
    /// Asserts that a journal another program reads for a moment, as the watchdog does, is still
    /// replaced and deleted once it let go.
    /// </summary>
    [Fact]
    public void Journal_ReadElsewhereForAMoment_IsStillWritten()
    {
        WriteMod("Patch/A.rb", "# A\n");
        using var parking = Parking();
        parking.Park(["Patch/A.rb"], World);

        Assert.Equal(1, WhileReadForAMoment(parking.JournalPath, () => parking.Restore(false)));
        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.False(File.Exists(parking.JournalPath));

        parking.Park(["Patch/A.rb"], World);
        Assert.NotNull(WhileReadForAMoment(parking.JournalPath, () => parking.PrepareWatch(World, false)));
        Assert.Contains("after\ttitle", File.ReadAllLines(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that a restore that brought every mod back answers their count even when the empty
    /// parking folders cannot be removed.
    /// </summary>
    [Fact]
    public void Restore_FoldersThatStay_StillCountsTheMods()
    {
        WriteMod("Patch/Sub/A.rb", "# A\n");
        using var parking = Parking();
        parking.Park(["Patch/Sub/A.rb"], World);
        var stuck = Directory.CreateDirectory(GamePath("Parked mods/Patch/Stuck"));
        stuck.Attributes |= FileAttributes.ReadOnly;

        try
        {
            Assert.Equal(1, parking.Restore(false));
            Assert.True(File.Exists(GamePath("Patch/Sub/A.rb")));
            Assert.False(File.Exists(parking.JournalPath));
            Assert.True(Directory.Exists(stuck.FullName));
        }
        finally
        {
            stuck.Refresh();
            stuck.Attributes &= ~FileAttributes.ReadOnly;
        }
    }

    /// <summary>
    /// Asserts that a move that fails puts back every mod the same park moved and leaves no journal.
    /// </summary>
    [Fact]
    public void Park_AFailedMove_PutsEverythingBack()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Patch/B.rb", "# B\n");
        using var parking = Parking();

        // An open file without delete sharing cannot be renamed, so the second move fails.
        using (new FileStream(GamePath("Patch/B.rb"), FileMode.Open, FileAccess.Read, FileShare.Read))
        {
            Assert.Equal(0, parking.Park(["Patch/A.rb", "Patch/B.rb"], World));
        }

        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Patch/B.rb")));
        Assert.False(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        Assert.False(File.Exists(parking.JournalPath));
    }

    /// <summary>
    /// Asserts what a game finds as it starts: nothing without a journal, the mods kept parked when it
    /// rejoins their world, and brought back when it does not.
    /// </summary>
    [Fact]
    public void Recover_KeepsTheModsForTheirWorldAndBringsThemBackOtherwise()
    {
        WriteMod("Patch/A.rb", "# A\n");
        using var parking = Parking();

        Assert.Equal(0, parking.Recover(World));

        parking.Park(["Patch/A.rb"], World);
        Assert.Equal(2, parking.Recover(World));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));

        Assert.Equal(1, parking.Recover(string.Empty));
        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.False(File.Exists(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that a crash right after a move, before the journal said so, still brings the mod back,
    /// and that a crash before the first move leaves nothing to restore.
    /// </summary>
    [Fact]
    public void Recover_AfterACrash_FindsWhatTheJournalNames()
    {
        var hash = WriteMod("Parked mods/Patch/A.rb", "# A\n");
        WriteMod("Parked mods/Parked.txt", $"world\t{World}\nafter\tnone\nfile\tPatch/A.rb\t{hash}\t0\n");
        using var parking = Parking();

        Assert.Equal("Patch/A.rb", Message.Decode(parking.Describe()).Team);
        Assert.Equal(1, parking.Recover(OtherWorld));
        Assert.Equal("# A\n", File.ReadAllText(GamePath("Patch/A.rb")));

        WriteMod("Parked mods/Parked.txt", $"world\t{World}\nafter\tnone\nfile\tPatch/A.rb\t{new string('a', 64)}\t0\n");
        Assert.Equal(0, parking.Recover(World));
        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.False(File.Exists(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that a journal that names a mod not yet moved parks it anew, and keeps a moved one parked.
    /// </summary>
    [Fact]
    public void Park_AfterACrashBeforeAMove_ParksTheModAnew()
    {
        WriteMod("Patch/A.rb", "# A\n");
        WriteMod("Parked mods/Patch/B.rb", "# B\n");
        WriteMod("Parked mods/Parked.txt", $"world\t{World}\nafter\tnone\nfile\tPatch/A.rb\t{new string('a', 64)}\t0\nfile\tPatch/B.rb\t{new string('b', 64)}\t1\n");
        using var parking = Parking();

        Assert.Equal(2, parking.Park(["Patch/A.rb", "Patch/B.rb"], World));

        Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/B.rb")));
        Assert.Equal(2, File.ReadAllLines(parking.JournalPath).Count(line => line.StartsWith("file\t", StringComparison.Ordinal) && line.EndsWith("\t1", StringComparison.Ordinal)));
    }

    /// <summary>
    /// Asserts that a mod put into Patch again while parked is parked anew, its older parked copy
    /// going to the conflicts folder, so the game never loads it.
    /// </summary>
    [Fact]
    public void Park_AModPutBackWhileParked_ParksTheNewCopy()
    {
        WriteMod("Patch/A.rb", "# A 1.0\n");
        using var parking = new ModParking(_game.Path) { InOptionsDump = () => false, Clock = () => new DateTime(2026, 10, 9, 21, 0, 0) };
        parking.Park(["Patch/A.rb"], World);
        WriteMod("Patch/A.rb", "# A 2.0\n");

        Assert.Equal(1, parking.Park(["Patch/A.rb"], World));

        Assert.False(File.Exists(GamePath("Patch/A.rb")));
        Assert.Equal("# A 2.0\n", File.ReadAllText(GamePath("Parked mods/Patch/A.rb")));
        Assert.Equal("# A 1.0\n", File.ReadAllText(GamePath("Parked mods/Conflicts/2026-10-09 21-00-00/Patch/A.rb")));
    }

    /// <summary>
    /// Asserts that the lock in this mod's folder makes no parking folder as the game starts, keeps a
    /// second game of the same folder from parking, restoring and recovering while the first holds
    /// it, lets that game restore once the first let it go, and goes with the game that held it.
    /// </summary>
    [Fact]
    public void Lock_KeepsASecondGameOut()
    {
        WriteMod("Patch/A.rb", "# A\n");
        var first = Parking();
        first.Begin();
        Assert.Equal(Path.Combine(_game.Path, "Patch", "Multiplayer", "Parking.lock"), first.LockPath);
        Assert.True(File.Exists(first.LockPath));
        Assert.False(Directory.Exists(GamePath("Parked mods")));

        first.Park(["Patch/A.rb"], World);
        using var second = Parking();

        Assert.Equal(0, second.Park(["Patch/A.rb"], OtherWorld));
        Assert.Equal(ModParking.HeldElsewhere, second.Restore(false));
        Assert.Equal(ModParking.HeldElsewhere, second.Recover(string.Empty));
        Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));

        first.Dispose();
        Assert.False(File.Exists(first.LockPath));
        Assert.Equal(1, second.Restore(false));
        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.False(Directory.Exists(GamePath("Parked mods")));
    }

    /// <summary>
    /// Asserts that a game whose lock another game holds answers a restore with nothing to do while
    /// no mod is parked, so leaving a world never reports the other game.
    /// </summary>
    [Fact]
    public void Lock_HeldElsewhereWithNothingParked_RestoresNothing()
    {
        using var first = Parking();
        first.Begin();
        using var second = Parking();

        Assert.Equal(0, second.Restore(true));
        Assert.Equal(0, second.Recover(string.Empty));
    }

    /// <summary>
    /// Asserts that a game started for the options dump never parks, nor recovers.
    /// </summary>
    [Fact]
    public void OptionsDump_NeverParks()
    {
        WriteMod("Patch/A.rb", "# A\n");
        using var parking = new ModParking(_game.Path) { InOptionsDump = () => true };

        Assert.Equal(0, parking.Park(["Patch/A.rb"], World));
        Assert.Equal(0, parking.Recover(string.Empty));
        Assert.True(File.Exists(GamePath("Patch/A.rb")));
        Assert.False(File.Exists(parking.LockPath));
        Assert.False(Directory.Exists(GamePath("Parked mods")));
    }

    /// <summary>
    /// Asserts that the journal names the watchdog it belongs to and what happens afterwards, and an
    /// update asked for; that the update mark comes off again, and that a later park or watchdog
    /// resets what happens afterwards and the update mark.
    /// </summary>
    [Fact]
    public void Journal_NamesTheWatchdogAndTheUpdate()
    {
        WriteMod("Patch/A.rb", "# A\n");
        using var parking = Parking();
        Assert.NotNull(parking.PrepareWatch(World, false));
        Assert.False(File.Exists(parking.JournalPath));

        parking.Park(["Patch/A.rb"], World);
        var watch = parking.PrepareWatch(World, false);
        parking.MarkUpdate(true);

        var lines = File.ReadAllLines(parking.JournalPath);
        Assert.Contains("after\ttitle", lines);
        Assert.Contains($"watch\t{watch}", lines);
        Assert.Contains("update\t1", lines);
        Assert.Matches("^[0-9a-f]{16}$", watch);

        parking.MarkUpdate(false);
        Assert.DoesNotContain("update\t1", File.ReadAllLines(parking.JournalPath));

        parking.MarkUpdate(true);
        parking.Park(["Patch/A.rb"], OtherWorld);
        lines = File.ReadAllLines(parking.JournalPath);
        Assert.Contains("after\tnone", lines);
        Assert.DoesNotContain("update\t1", lines);

        parking.MarkUpdate(true);
        parking.PrepareWatch(OtherWorld, true);
        Assert.DoesNotContain("update\t1", File.ReadAllLines(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that mods are told apart by their keys as the game script and the catalog do.
    /// </summary>
    [Fact]
    public void KeyOf_DropsCaseExtensionAndSeparators() =>
        Assert.Equal(["0modconfigremake", "victoryscreen", "patch"], new[] { "0_Mod Config-Remake.rb", "Victory_Screen.RB", "Patch" }.Select(ModParking.KeyOf));

    /// <inheritdoc />
    public void Dispose()
    {
        foreach (var junction in Enumerable.Reverse(_junctions))
        {
            Directory.Delete(junction);
        }

        ClearReadOnly(_game.Path);
        _game.Dispose();
    }

    /// <summary>
    /// Clears the read-only attribute of every file in a folder, which would keep it from being deleted.
    /// </summary>
    /// <param name="folder">The folder.</param>
    internal static void ClearReadOnly(string folder)
    {
        foreach (var file in Directory.EnumerateFiles(folder, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(file, File.GetAttributes(file) & ~FileAttributes.ReadOnly);
        }
    }

    /// <summary>
    /// Makes the parking of the test's game folder, outside the options dump.
    /// </summary>
    /// <returns>The parking, which the test disposes to let its lock go.</returns>
    private ModParking Parking() => new(_game.Path) { InOptionsDump = () => false };

    /// <summary>
    /// Runs a step while another thread holds a file open for reading without delete sharing, as
    /// File.ReadAllLines does, and lets it go a moment later.
    /// </summary>
    /// <typeparam name="T">What the step answers.</typeparam>
    /// <param name="path">The file.</param>
    /// <param name="step">The step.</param>
    /// <returns>What the step answered.</returns>
    private static T WhileReadForAMoment<T>(string path, Func<T> step)
    {
        using var opened = new ManualResetEventSlim();
        var reader = Task.Run(() =>
        {
            using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
            opened.Set();
            Thread.Sleep(150);
        });

        opened.Wait();
        var answer = step();
        reader.Wait();
        return answer;
    }

    /// <summary>
    /// Makes a junction in the test's game folder, which needs no rights a symbolic link would.
    /// </summary>
    /// <param name="link">The junction's path relative to the game folder.</param>
    /// <param name="target">The folder it leads to, relative to the game folder.</param>
    private void Junction(string link, string target)
    {
        var start = new ProcessStartInfo("cmd.exe") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true };
        start.ArgumentList.Add("/c");
        start.ArgumentList.Add("mklink");
        start.ArgumentList.Add("/J");
        start.ArgumentList.Add(GamePath(link).Replace('/', '\\'));
        start.ArgumentList.Add(GamePath(target).Replace('/', '\\'));
        using var process = Process.Start(start)!;
        process.StandardOutput.ReadToEnd();
        process.WaitForExit();
        Assert.Equal(0, process.ExitCode);
        _junctions.Add(GamePath(link));
    }

    /// <summary>
    /// Writes a file into the test's game folder.
    /// </summary>
    /// <param name="relative">Its path relative to the game folder.</param>
    /// <param name="text">Its text.</param>
    /// <returns>Its hash, see <see cref="ModHash"/>.</returns>
    private string WriteMod(string relative, string text)
    {
        var path = GamePath(relative);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, text);
        return ModHash.OfFile(path);
    }

    /// <summary>
    /// Builds the full path of a file in the test's game folder.
    /// </summary>
    /// <param name="relative">Its path relative to the game folder.</param>
    /// <returns>The full path.</returns>
    private string GamePath(string relative) => Path.Combine(_game.Path, relative);
}
