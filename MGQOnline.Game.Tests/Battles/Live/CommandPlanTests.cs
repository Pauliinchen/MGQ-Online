//----------------------------------------------------------------
//  CommandPlanTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Tests.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the host's plan of a guest's commands, replayed from the golden cases of
/// fixtures/live/plan.json, which battles_sync.rbx's Commands.apply gave before its checks left
/// it, and the team duel's sides, replayed from team.json.
/// </summary>
public sealed class CommandPlanTests
{
    /// <summary>
    /// The actions each character of the golden cases takes.
    /// </summary>
    private const int ActionsTaken = 2;

    /// <summary>
    /// The skills every character of the golden cases has: those below this id.
    /// </summary>
    private const int KnownSkills = 150;

    /// <summary>
    /// The items of the golden cases a battle allows: those below this id.
    /// </summary>
    private const int BattleItems = 40;

    /// <summary>
    /// The skill of the golden cases that has no skill type, which every character may use.
    /// </summary>
    private const int TypelessSkill = 199;

    /// <summary>
    /// Asserts that every character of the golden cases ends with the actions the script gave it.
    /// </summary>
    [Fact]
    public void Commands_GiveTheActionsTheScriptGave()
    {
        foreach (JsonElement entry in Fixtures.Read("live", "plan.json").GetProperty("cases").EnumerateArray())
        {
            Dictionary<int, int> heirs = entry.GetProperty("heirs").EnumerateArray().ToDictionary(pair => pair[0].GetInt32(), pair => pair[1].GetInt32());
            List<int?> owners = entry.GetProperty("owners").EnumerateArray().Select(owner => owner.ValueKind == JsonValueKind.Null ? null : (int?)owner.GetInt32()).ToList();
            JsonElement seat = entry.GetProperty("seat");
            List<List<PlannedCommand?>?>? plan = CommandPlan.Plan(Encoding.UTF8.GetBytes(entry.GetProperty("body").GetString()!),
                seat.ValueKind == JsonValueKind.Null ? null : seat.GetInt32(), entry.GetProperty("several").GetBoolean(), owners,
                left => heirs.TryGetValue(left, out int heir) ? heir : null, entry.GetProperty("skills").GetInt32(), entry.GetProperty("items").GetInt32());
            string actual = new JsonArray(owners.Select((_, place) => Given(plan?[place])).ToArray()).ToJsonString();
            Assert.True(WireDescription.Canonical(entry.GetProperty("places")) == actual, $"{entry.GetProperty("name").GetString()}: {actual}");
        }
    }

    /// <summary>
    /// Asserts that a chain of 17 skills is cut to 16.
    /// </summary>
    [Fact]
    public void Plan_ChainOfSeventeen_TakesSixteen()
    {
        WireValue[] chain = Enumerable.Range(20, 17).Select(id => (WireValue)new WireList("skill", id, 0)).ToArray();
        string body = WireWriter.Line(new WireList(new WireList(new WireList("skill", 5, 0, new WireList(chain)))));

        List<List<PlannedCommand?>?>? plan = CommandPlan.Plan(Encoding.UTF8.GetBytes(body), null, false, [null], _ => null, 200, 50);

        Assert.Equal(Enumerable.Range(20, CommandPlan.MaxChain), Assert.Single(Assert.Single(plan!)!)!.Chain!.Select(link => link.Id));
    }

    /// <summary>
    /// Asserts that a target of -1, a random one, is read, and -2 is not.
    /// </summary>
    [Fact]
    public void Plan_TargetMinusOne_IsARandomTarget()
    {
        string body = WireWriter.Line(new WireList(new WireList(new WireList("skill", 5, -1), new WireList("skill", 5, -2))));

        List<PlannedCommand?> commands = CommandPlan.Plan(Encoding.UTF8.GetBytes(body), 2, false, [null], _ => null, 200, 50)![0]!;

        Assert.Equal(-1, commands[0]!.Target);
        Assert.Null(commands[1]);
    }

    /// <summary>
    /// Asserts that the team duel's sides settle and take who commands the characters of who left as
    /// the script did.
    /// </summary>
    [Fact]
    public void Sides_SettleAndTakeHeirsAsTheScriptDid()
    {
        var session = new LiveSession();
        var sides = new TeamSides();
        int host = 0;
        foreach (JsonElement step in Fixtures.Read("live", "team.json").GetProperty("steps").EnumerateArray())
        {
            string op = step.GetProperty("op").GetString()!;
            string? posted = null;
            bool broken = false;
            JsonNode? value = null;
            switch (op)
            {
                case "join":
                    List<int> own = step.GetProperty("own").EnumerateArray().Select(seat => seat.GetInt32()).ToList();
                    List<int> other = step.GetProperty("other").EnumerateArray().Select(seat => seat.GetInt32()).ToList();
                    bool same = step.GetProperty("same_side").GetBoolean();
                    host = same ? own[0] : other[0];
                    session.Join(same ? "host" : "guest", "t", same ? own.Concat(other).Where(seat => seat != host).ToList() : [host], "the duel", "pvp", true, false);
                    session.Start();
                    sides.Prepare(own, other, same);
                    break;
                case "same_side":
                    value = sides.SameSideAsHost(step.GetProperty("seat").GetInt32());
                    break;
                case "left":
                    session.GuestLeft(step.GetProperty("seat").GetInt32());
                    break;
                case "settle":
                    posted = sides.Settle(host, session.GuestsIn) ? sides.HeirsLine() : null;
                    break;
                case "heir":
                    value = sides.HeirOf(step.GetProperty("seat").GetInt32());
                    break;
                case "gone":
                    value = sides.OtherSideGone(host, session.GuestsIn);
                    break;
                case "take":
                    broken = sides.TakeHeirs(Encoding.UTF8.GetBytes(step.GetProperty("body").GetString()!));
                    break;
            }

            string label = $"{op} {step}";
            Assert.True(WireDescription.Canonical(step.GetProperty("value")) == (value?.ToJsonString() ?? "null"), label);
            Assert.True(step.GetProperty("heirs").EnumerateArray().Select(pair => (pair[0].GetInt32(), pair[1].ValueKind == JsonValueKind.Null ? (int?)null : pair[1].GetInt32()))
                .SequenceEqual(sides.Heirs.Select(pair => (pair.Key, pair.Value))), label);
            Assert.Equal(step.GetProperty("posted").EnumerateArray().Select(body => body.GetString()), posted is null ? [] : new[] { posted });
            Assert.Equal(step.GetProperty("logs").GetArrayLength() > 0, broken);
        }
    }

    /// <summary>
    /// Writes the actions a planned place gives a character, as the golden cases note them, with
    /// every character taking two actions and using only what it may.
    /// </summary>
    /// <param name="place">The place's plan.</param>
    /// <returns>"kept" for the computer's, else each action as [kind, id, target, chain].</returns>
    private static JsonNode Given(List<PlannedCommand?>? place)
    {
        if (place is null)
        {
            return "kept";
        }

        if (place.Count == 0)
        {
            return new JsonArray();
        }

        var actions = new JsonArray();
        foreach (PlannedCommand command in place.Take(ActionsTaken).OfType<PlannedCommand>().Where(Allowed))
        {
            var chain = new JsonArray();
            foreach (PlannedCommand link in (command.Chain ?? []).TakeWhile(Allowed))
            {
                chain.Add(new JsonArray(link.Kind, link.Id, link.Target));
            }

            actions.Add(new JsonArray(command.Kind, command.Id, command.Target, chain));
        }

        return actions.Count == 0 ? "kept" : actions;
    }

    /// <summary>
    /// Reports whether a character of the golden cases may use a skill or item.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it may.</returns>
    private static bool Allowed(PlannedCommand command) =>
        command.Kind == "item" ? command.Id < BattleItems : command.Id < KnownSkills || command.Id == TypelessSkill;
}
