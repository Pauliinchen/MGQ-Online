//----------------------------------------------------------------
//  WorldFormsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Wrote the world's rules out, walked every form for its hints and dropped the recorded cases
//      Paulinchen  2026-11-05: Covered every field's hint fitting the world screen's two lines
//                            - Expected the world type, sharing, shared save and player's choice in the new world's sums alone
//      Paulinchen  2026-10-23: Covered Enter sending a form
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Forms;

namespace MGQOnline.Game.Tests.Forms;

/// <summary>
/// Covers the world screen's forms.
/// </summary>
public sealed class WorldFormsTests
{
    /// <summary>
    /// The most characters a field's hint takes, which fill the two lines at the top of the world screen.
    /// </summary>
    private const int MaxHintChars = 100;

    /// <summary>
    /// The rules the DLL tells: 2 to 32 seats, the game's difficulties and the squad's limits.
    /// </summary>
    private static readonly WorldFormRules Rules = new(
        2, 32, 4, [(-2, "VERY EASY"), (-1, "EASY"), (0, "NORMAL"), (1, "HARD"), (2, "VERY HARD"), (3, "HELL"), (4, "PARADOX")], 0,
        [(0, "Original"), (4, "4"), (5, "5"), (6, "6"), (7, "7"), (8, "8")], [1, 2, 3, 4], new WorldSquad(false, 4, 1, 1));

    /// <summary>
    /// Asserts that a checkbox the player ticked no longer follows the world type.
    /// </summary>
    [Fact]
    public void Turn_LeavesACheckboxThePlayerTickedAlone()
    {
        Form form = WorldForms.OpenCreate(Rules);
        FormField type = form.Field(Form.MainPage, "type")!;

        form.Turn(type, 1);
        Assert.True(form.IsTicked("other_mods_off"));
        form.Tick("other_mods_off");
        form.Turn(type, 1);
        form.Turn(type, 1);

        Assert.False(form.IsTicked("other_mods_off"));
    }

    /// <summary>
    /// Asserts that every field's hint fits the two lines at the top of the world screen, those of a
    /// Raid World, its formation limits and the edit forms too.
    /// </summary>
    [Fact]
    public void Hints_FitTwoLines()
    {
        Form raid = WorldForms.OpenCreate(Rules);
        raid.Turn(raid.Field(Form.MainPage, "type")!, 1);
        var raidWorld = new EditedWorld("Raid", 4, "", "", false, null, true, true, true, Rules.DefaultSquad);
        Form[] forms =
        [
            WorldForms.OpenCreate(Rules), raid, WorldForms.OpenEdit(Rules, raidWorld, own: true),
            WorldForms.OpenRename("World", discord: true), WorldForms.OpenPassword("World"), WorldForms.OpenJoin(),
        ];

        foreach (Form form in forms)
        {
            Assert.All(form.Fields(), field => Assert.True(field.Hint.Length <= MaxHintChars, field.Key));
        }

        Assert.All(raid.Fields(WorldForms.LimitsPage), field => Assert.True(field.Hint.Length <= MaxHintChars, field.Key));
    }

    /// <summary>
    /// Asserts that Enter sends the forms of one text box only, never the new world's.
    /// </summary>
    [Fact]
    public void SendsOnEnter_OnlyTheFormsOfOneTextBox()
    {
        Assert.True(WorldForms.SendsOnEnter(WorldForms.OpenRename("", discord: false)));
        Assert.True(WorldForms.SendsOnEnter(WorldForms.OpenJoin()));
        Assert.False(WorldForms.SendsOnEnter(WorldForms.OpenCreate(Rules)));
    }
}
