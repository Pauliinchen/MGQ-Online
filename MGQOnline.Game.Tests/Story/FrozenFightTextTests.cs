//----------------------------------------------------------------
//  FrozenFightTextTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers a frozen raid boss fight's text on the relay's story tracks: one an earlier release wrote
/// reads to the fight and is written back the same, broken ones read as none, and one longer than
/// the relay keeps is never written.
/// </summary>
public sealed class FrozenFightTextTests
{
    /// <summary>
    /// A fight as world_freeze.rbx of release 0.6.9 wrote it, its free texts holding every separator.
    /// </summary>
    private const string Released =
        "map:138:13:1|ce:154|1|138|13:32:8:2:1:$Sonya!%7C%3B%2C%3A%25%7E%3D%2E%E3%82%BD%E3%83%8B%E3%82%A2:0:0:255:0:1:1:1,14:30:8:6:0:Luka:2:0:255:0:-1:0:1|13.14|138.30.10.8|" +
        "v1075~n14,v2001~sYXxiO2MsZDplJWZ%2BZz1oLmkgw7w%3D,v2002~f1%2E5,v2003~n-7,s31~F,s32~T,x138.13.A~F,x138.14.B%7C%3B~T";

    /// <summary>
    /// Asserts that a fight an earlier release wrote reads to its values, the names, a text and a
    /// Float among them, and is written back byte for byte.
    /// </summary>
    [Fact]
    public void Read_TakesAFightAnEarlierReleaseWroteAndWritesItTheSame()
    {
        RubyHash? fight = FrozenFightText.Read(868, Released);

        Assert.Equal(Fight(), fight);
        Assert.Equal(Released, FrozenFightText.Write(fight!));
    }

    /// <summary>
    /// Asserts that a fight missing a field, holding an escape that is none, or whose tableau has no
    /// boss row reads as none.
    /// </summary>
    [Fact]
    public void Read_DropsABrokenFight()
    {
        string[] broken = [Released[(Released.IndexOf('|') + 1)..], Released.Replace("Luka", "Lu%zka"), Released.Replace("255:0:1:1:1,", "255:0:1:0:1,")];

        Assert.All(broken, text => Assert.Null(FrozenFightText.Read(868, text)));
    }

    /// <summary>
    /// Asserts that a fight whose text would be longer than the relay keeps is never written.
    /// </summary>
    [Fact]
    public void Write_LeavesOutAFightLongerThanTheRelayKeeps()
    {
        RubyHash fight = Fight();
        fight["held"] = new RubyArray(Enumerable.Range(1, 300).Select(id => (RubyValue)new RubyArray { 1, 2000 + id, new string('x', 200) }));

        Assert.Null(FrozenFightText.Write(fight));
    }

    /// <summary>
    /// Makes the fight of <see cref="Released"/> as the scripts hand it over.
    /// </summary>
    /// <returns>The fight.</returns>
    private static RubyHash Fight() => new()
    {
        { "troop", 868 },
        { "site", new RubyArray { "map", 138, 13, 1 } },
        { "outer", new RubyArray { "ce", 154 } },
        { "scene", true },
        {
            "tableau", new RubyArray
            {
                138,
                new RubyArray
                {
                    new RubyArray { 13, 32, 8, 2, 1, "$Sonya!|;,:%~=.ソニア", 0, 0, 255, 0, 1, 1, 1 },
                    new RubyArray { 14, 30, 8, 6, 0, "Luka", 2, 0, 255, 0, -1, 0, 1 },
                },
                new RubyArray { 13, 14 },
            }
        },
        { "spot", new RubyArray { 138, 30, 10, 8 } },
        {
            "held", new RubyArray
            {
                new RubyArray { 1, 1075, 14 }, new RubyArray { 1, 2001, "a|b;c,d:e%f~g=h.i ü" }, new RubyArray { 1, 2002, new RubyHash { { "float", "1.5" } } },
                new RubyArray { 1, 2003, -7 }, new RubyArray { 0, 31, false }, new RubyArray { 0, 32, true },
                new RubyArray { 2, new RubyArray { 138, 13, "A" }, false }, new RubyArray { 2, new RubyArray { 138, 14, "B|;" }, true },
            }
        },
    };
}
