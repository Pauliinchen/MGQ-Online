//----------------------------------------------------------------
//  ShippedChoicesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Named the choices by their number among their list's commands of their code, without the list's shape
//      Paulinchen  2026-11-06: Read the relay's seed through TableFiles
//      Paulinchen  2026-11-01: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Catchup;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers which choices of the story's branch events a replay asks its receiver, over the events
/// database the mod ships and the keys the reviewed list makes each player's own: every choice on
/// the way to an outcome of its own, an extended choice too.
/// </summary>
public sealed class ShippedChoicesTests : IDisposable
{
    /// <summary>
    /// The shipped file's path below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// The events database the mod ships.
    /// </summary>
    private readonly EventStore _store = EventStore.Open(ShippedFile());

    /// <summary>
    /// The keys each player keeps by the reviewed list.
    /// </summary>
    private readonly HashSet<StoryKey> _personal = [.. PersonalKeys()];

    /// <summary>
    /// Asserts that every choice of Plansect Village is the receiver's: at the Queen Bee (134:34),
    /// fighting her (the Priestess's side), helping the insects or talking, then challenging her
    /// anyway or not, after the talk challenging her, allying with the insects or talking to the
    /// plants, each a jump to its part, and later challenging her or not; at the Priestess
    /// (132:23), fighting her (the Queen Bee's side), persuading her (the way to the peace in which
    /// both queens join) or nothing, then challenging her anyway or not.
    /// </summary>
    [Fact]
    public void Plansect_AsksEveryChoiceOnTheWayToEachOutcome()
    {
        Assert.Equal([0, 1, 2, 3], Asked(ReplaySite.Page(134, 34, 0)));
        Assert.Equal([0, 1], Asked(ReplaySite.Page(132, 23, 0)));
    }

    /// <summary>
    /// Asserts that the Sphinx's challenges are the receiver's, each a jump to the battle after its
    /// choice, whose win is the receiver's own outcome.
    /// </summary>
    [Fact]
    public void Sphinx_AsksTheChallengesThatJumpToTheBattle()
    {
        Assert.Equal([0, 1, 2, 3, 4], Asked(ReplaySite.Page(117, 6, 0)));
    }

    /// <summary>
    /// Asserts that the Colosseum's choice of a cup (CE 161), an extended choice, is the receiver's,
    /// since each cup wins its own prize.
    /// </summary>
    [Fact]
    public void Colosseum_AsksTheCupToEnter()
    {
        Assert.Equal([1], Asked(ReplaySite.Parse("ce:161")));
    }

    /// <inheritdoc />
    public void Dispose() => _store.Dispose();

    /// <summary>
    /// Lists the choices of a page or common event a replay asks its receiver, as the receiver's game
    /// of the shipped data names them: its Show Choices commands and the script commands of its
    /// extended choices.
    /// </summary>
    /// <param name="site">The page or common event.</param>
    /// <returns>Each choice's number among the list's commands of its code.</returns>
    private int[] Asked(ReplaySite site)
    {
        int listId = site.IsCommon ? _store.CommonList(site.CommonId)!.Value.ListId : _store.Page(site.MapId, site.EventId, site.PageNo)!.Value.ListId;
        var match = new PageMatch(_store);
        CommandRow[] choices = [.. _store.Commands(listId).Where(command => command.Code is EventCodes.ShowChoices or EventCodes.Script)];
        return [.. choices.Select(command => choices.Count(before => before.Code == command.Code && before.Idx < command.Idx))
            .Where((number, index) => match.IsReceivers(site, StoryPlain.PlaceText(site.ToString(), choices[index].Code, number), _personal.Contains))];
    }

    /// <summary>
    /// Reads the keys the reviewed list makes each player's own.
    /// </summary>
    /// <returns>The keys.</returns>
    private static IEnumerable<StoryKey> PersonalKeys()
    {
        foreach (JsonElement row in TableFiles.Rows("keys"))
        {
            if (row.GetProperty("kind").GetString() == "personal" && StoryKey.TryParse(row.GetProperty("key").GetString(), out StoryKey key))
            {
                yield return key;
            }
        }
    }

    /// <summary>
    /// Finds the shipped file in the repository the tests were built in.
    /// </summary>
    /// <returns>Its full path.</returns>
    private static string ShippedFile()
    {
        for (DirectoryInfo? folder = new(AppContext.BaseDirectory); folder is not null; folder = folder.Parent)
        {
            string path = Path.Combine(folder.FullName, ShippedPath);
            if (File.Exists(path))
            {
                return path;
            }
        }

        throw new FileNotFoundException($"{ShippedPath} is in no folder above {AppContext.BaseDirectory}");
    }
}
