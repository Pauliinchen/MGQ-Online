//----------------------------------------------------------------
//  TranslatedListsRealGameTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the names a story replay gives the inputs of a run (story_replay.rbx input_at): a command's
/// code and its number among its list's commands of that code, compared between the events database
/// the mod ships, built from the untranslated game, and the game BATTLE_GAME_DIR names, the
/// translated one in the tests' install.
/// </summary>
/// <remarks>
/// Draws and the inputs of branches and scripts are left out: their codes run for more than inputs,
/// and a translation adds branches, variables and scripts.
/// </remarks>
public sealed class TranslatedListsRealGameTests : IDisposable
{
    /// <summary>
    /// The shipped events database below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// The codes whose commands are inputs only: Show Choices, Input Number, Select Key Item and
    /// Battle Processing.
    /// </summary>
    private static readonly int[] InputCodes = [EventCodes.ShowChoices, EventCodes.InputNumber, EventCodes.SelectKeyItem, EventCodes.Battle];

    /// <summary>
    /// The events database the mod ships.
    /// </summary>
    private readonly EventStore _store = EventStore.Open(Path.Combine(Repository.Root, ShippedPath));

    /// <summary>
    /// Asserts that every map page and common event of the installed game holds its choices, number
    /// and item inputs and battles in the shipped database's order, so each of them keeps its number
    /// among its code's commands in either language.
    /// </summary>
    [Fact]
    public void EveryList_KeepsItsInputsInTheShippedOrder()
    {
        EventStore installed = GameFolder.StoreOrSkip();
        var defects = new List<string>();
        int lists = 0;

        foreach (int map in _store.MapIds())
        {
            foreach (PageRow page in _store.Pages(map))
            {
                lists++;
                Compare($"map {map} event {page.EventId} page {page.PageNo + 1}", page.ListId, installed.ListOf(map, page.EventId, page.PageNo)?.ListId, installed, defects);
            }
        }

        foreach (int common in _store.CommonIds())
        {
            lists++;
            Compare($"common event {common}", _store.CommonList(common)!.Value.ListId, installed.CommonList(common)?.ListId, installed, defects);
        }

        Assert.True(lists > 0, "the shipped database holds no list");
        Assert.Empty(defects);
    }

    /// <inheritdoc />
    public void Dispose() => _store.Dispose();

    /// <summary>
    /// Compares the inputs of a list in the shipped database and the installed game.
    /// </summary>
    /// <param name="name">The list, for a defect.</param>
    /// <param name="shippedId">The list in the shipped database.</param>
    /// <param name="installedId">The list in the installed game, <see langword="null"/> when it lacks it.</param>
    /// <param name="installed">The installed game's events database.</param>
    /// <param name="defects">The defects found so far.</param>
    private void Compare(string name, int shippedId, int? installedId, EventStore installed, List<string> defects)
    {
        if (installedId is not { } id)
        {
            defects.Add($"{name}: the installed game lacks it");
            return;
        }

        string shipped = InputsOf(_store.Commands(shippedId));
        string live = InputsOf(installed.Commands(id));
        if (shipped != live)
        {
            defects.Add($"{name}: shipped [{shipped}], installed [{live}]");
        }
    }

    /// <summary>
    /// Writes a list's input commands in order.
    /// </summary>
    /// <param name="commands">The list's commands.</param>
    /// <returns>Their codes.</returns>
    private static string InputsOf(IEnumerable<CommandRow> commands) =>
        string.Join(" ", commands.Where(command => InputCodes.Contains(command.Code)).Select(command => command.Code));
}
