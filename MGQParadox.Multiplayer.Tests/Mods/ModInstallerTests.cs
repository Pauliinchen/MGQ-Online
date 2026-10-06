//----------------------------------------------------------------
//  ModInstallerTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Covered zips whose files sit in a Patch folder
//                            - Covered links to a zip of a release and zips written with backslashes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers installing a world's mods into the Patch folder: only files with the catalog's hashes,
/// only inside Patch, and nothing at all when one differs.
/// </summary>
public sealed class ModInstallerTests
{
    /// <summary>
    /// A script as GitHub serves it.
    /// </summary>
    private static readonly byte[] Script = Encoding.UTF8.GetBytes("# Level Cap\nputs 1\n");

    /// <summary>
    /// Asserts that a link mod's script lands where the game script said, replacing the old copy.
    /// </summary>
    [Fact]
    public void Install_LinkMod_WritesTheScript()
    {
        using var game = new TempFolder();
        Directory.CreateDirectory(Path.Combine(game.Path, "Patch", "Mods"));
        File.WriteAllText(Path.Combine(game.Path, "Patch", "Mods", "Level Cap.rb"), "old");

        var written = ModInstaller.Install([(LinkMod(ModHash.Of("Level_Cap.rb", Script)), "Patch/Mods/Level Cap.rb")], _ => Script, game.Path);

        Assert.Equal([Path.Combine("Patch", "Mods", "Level Cap.rb")], written);
        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Mods", "Level Cap.rb")));
    }

    /// <summary>
    /// Asserts that a download that differs from the catalog leaves every mod as it was.
    /// </summary>
    [Fact]
    public void Install_DifferingScript_WritesNothing()
    {
        using var game = new TempFolder();
        var good = LinkMod(ModHash.Of("Level_Cap.rb", Script));
        var bad = LinkMod("00" + ModHash.Of("Level_Cap.rb", Script)[2..]) with { Key = "other", Name = "Other" };

        var error = Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(good, "Patch/Level_Cap.rb"), (bad, "Patch/Other.rb")], _ => Script, game.Path));

        Assert.Contains("Other", error.Message);
        Assert.False(File.Exists(Path.Combine(game.Path, "Patch", "Level_Cap.rb")));
    }

    /// <summary>
    /// Asserts that a link mod never lands outside Patch or as anything but a script.
    /// </summary>
    [Fact]
    public void Install_LinkModOutsidePatch_IsRefused()
    {
        using var game = new TempFolder();
        var mod = LinkMod(ModHash.Of("Level_Cap.rb", Script));

        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(mod, "Data/Level_Cap.rb")], _ => Script, game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(mod, "Patch/../Level_Cap.rb")], _ => Script, game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(mod, "Patch/Level_Cap.exe")], _ => Script, game.Path));
    }

    /// <summary>
    /// Asserts that an uploaded mod's files land at their paths inside Patch.
    /// </summary>
    [Fact]
    public void Install_Upload_WritesEachFileInsidePatch()
    {
        using var game = new TempFolder();
        var pack = Encoding.UTF8.GetBytes("LUKA pack");
        var mod = UploadMod(new() { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Luka_Replacer/Heroes/cecil.luka"] = ModHash.Of("cecil.luka", pack) });
        var zip = Zip(("Luka_Replacer.rb", Script), ("Luka_Replacer/Heroes/cecil.luka", pack));

        var written = ModInstaller.Install([(mod, string.Empty)], _ => zip, game.Path);

        Assert.Equal(2, written.Count);
        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Luka_Replacer.rb")));
        Assert.Equal(pack, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Luka_Replacer", "Heroes", "cecil.luka")));
    }

    /// <summary>
    /// Asserts that an uploaded mod whose zip lacks a file or holds another version is refused.
    /// </summary>
    [Fact]
    public void Install_UploadThatDiffers_IsRefused()
    {
        using var game = new TempFolder();
        var mod = UploadMod(new() { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Luka_Replacer/Heroes/a.luka"] = ModHash.Of("a.luka", [1]) });

        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(mod, string.Empty)], _ => Zip(("Luka_Replacer.rb", Script)), game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(mod, string.Empty)], _ => Zip(("Luka_Replacer.rb", Script), ("Luka_Replacer/Heroes/a.luka", [2])), game.Path));
        Assert.False(File.Exists(Path.Combine(game.Path, "Patch", "Luka_Replacer.rb")));
    }

    /// <summary>
    /// Asserts that a link to a zip of a release installs like an upload, even from a zip written with backslashes.
    /// </summary>
    [Fact]
    public void Install_LinkToZip_WritesEachFileInsidePatch()
    {
        using var game = new TempFolder();
        var pack = Encoding.UTF8.GetBytes("LUKA pack");
        var files = new Dictionary<string, string> { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Luka_Replacer/Heroes/cecil.luka"] = ModHash.Of("cecil.luka", pack) };
        var mod = new CatalogMod("lukareplacer", "Luka Replacer", "link", "1.0", files, [], "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.0/Luka_Replacer.zip", Archive: true);

        ModInstaller.Install([(mod, string.Empty)], _ => Zip(("Luka_Replacer.rb", Script), ("Luka_Replacer\\Heroes\\cecil.luka", pack)), game.Path);

        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Luka_Replacer.rb")));
        Assert.Equal(pack, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Luka_Replacer", "Heroes", "cecil.luka")));
    }

    /// <summary>
    /// Asserts that a zip whose files sit in a Patch folder installs them at their paths inside Patch.
    /// </summary>
    [Fact]
    public void Install_ZipWithPatchFolder_WritesEachFileInsidePatch()
    {
        using var game = new TempFolder();
        var pack = Encoding.UTF8.GetBytes("LUKA pack");
        var files = new Dictionary<string, string> { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Luka_Replacer/Heroes/cecil.luka"] = ModHash.Of("cecil.luka", pack) };
        var mod = new CatalogMod("lukareplacer", "Luka Replacer", "link", "1.0", files, [], "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.0/Luka_Replacer.zip", Archive: true);

        ModInstaller.Install([(mod, string.Empty)], _ => Zip(("Patch/Luka_Replacer.rb", Script), ("Patch/Luka_Replacer/Heroes/cecil.luka", pack)), game.Path);

        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Luka_Replacer.rb")));
        Assert.Equal(pack, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Luka_Replacer", "Heroes", "cecil.luka")));
        Assert.False(Directory.Exists(Path.Combine(game.Path, "Patch", "Patch")));
    }

    /// <summary>
    /// Makes a link mod of one script.
    /// </summary>
    /// <param name="hash">The script's hash in the catalog.</param>
    /// <returns>The mod.</returns>
    private static CatalogMod LinkMod(string hash) =>
        new("levelcap", "Level Cap", "link", "1.3.5", new Dictionary<string, string> { ["Level_Cap.rb"] = hash }, [], "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.3.5/Level_Cap.rb");

    /// <summary>
    /// Makes an uploaded mod.
    /// </summary>
    /// <param name="files">Its files' hashes by path.</param>
    /// <returns>The mod.</returns>
    private static CatalogMod UploadMod(Dictionary<string, string> files) => new("lukareplacer", "Luka Replacer", "upload", "1.0", files, [], string.Empty);

    /// <summary>
    /// Zips files.
    /// </summary>
    /// <param name="files">Each file's path and bytes.</param>
    /// <returns>The zip.</returns>
    internal static byte[] Zip(params (string Path, byte[] Bytes)[] files)
    {
        using var stream = new MemoryStream();

        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            foreach (var (path, bytes) in files)
            {
                using var entry = archive.CreateEntry(path).Open();
                entry.Write(bytes);
            }
        }

        return stream.ToArray();
    }
}
