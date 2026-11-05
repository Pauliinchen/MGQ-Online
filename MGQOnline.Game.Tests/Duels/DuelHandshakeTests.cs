//----------------------------------------------------------------
//  DuelHandshakeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Duels;

namespace MGQOnline.Game.Tests.Duels;

/// <summary>
/// Covers the duel handshake: each reason a duel ends with, a team duel
/// whose gathered player leaves, a challenge that goes stale as the world changes, and what the
/// handshake does while the scripts have not answered a need yet.
/// </summary>
public sealed class DuelHandshakeTests
{
    /// <summary>
    /// The team the challenger receives with an accept.
    /// </summary>
    private const string FriendTeam = "member=7;friend";

    /// <summary>
    /// Asserts that each reason a duel ends with reaches the other player.
    /// </summary>
    /// <param name="reason">The reason.</param>
    /// <param name="kind">The message that carries it: "decline" or "cancel".</param>
    [Theory]
    [InlineData("gone", "decline")]
    [InlineData("busy", "decline")]
    [InlineData("data", "decline")]
    [InlineData("team", "decline")]
    [InlineData("no", "decline")]
    [InlineData("off", "cancel")]
    [InlineData("late", "cancel")]
    public void Reason_ReachesTheOtherPlayer(string reason, string kind)
    {
        DuelHarness harness = reason is "off" or "late" ? Gathering() : Friend();
        DuelHandshake duel = harness.Duel;
        switch (reason)
        {
            case "gone": Accepted(harness); break;
            case "busy": duel.Invite(null, false); duel.Free = false; Accepted(harness); break;
            case "data": duel.Invite(null, false); Accepted(harness, DuelHarness.TeamBody(FriendTeam, "game-2")); break;
            case "team": duel.Invite(null, false); Accepted(harness, DuelHarness.TeamBody("no members")); break;
            case "no": duel.Decline(harness.At(2)!, "no"); break;
            case "off": duel.Free = false; harness.Frames(); break;
            default: harness.Message(2, ReadyBody("member=7;friend"), ("duel", "ready"), ("bid", "b1")); harness.Frames(DuelHandshake.ReadyFrames + 1); break;
        }

        string expected = kind == "decline" ? $"duel=decline\nreason={reason}\n\n" : $"duel=cancel\nreason={reason}\n\n";
        Assert.Contains(harness.Sent, entry => entry.Text == expected);
    }

    /// <summary>
    /// Asserts that a team duel whose gathered player left starts without them under no name, and
    /// that one whose other side all left is off for everyone called.
    /// </summary>
    [Fact]
    public void TeamDuel_GoesOnWithoutAPlayerWhoLeft()
    {
        DuelHarness harness = Gathering();
        harness.Message(3, ReadyBody("member=3;pal"), ("duel", "ready"), ("bid", "b1"));
        harness.Leave(3);
        harness.Party("me-p", [], -1);
        harness.Message(2, ReadyBody("member=7;friend"), ("duel", "ready"), ("bid", "b1"));
        harness.Frames();

        DuelStart start = Assert.Single(harness.Starts);
        Assert.Contains("\ts?\t", start.Sides, StringComparison.Ordinal);
        Assert.Equal([3, 2], harness.Sent.Where(entry => entry.Text.StartsWith("duel=start", StringComparison.Ordinal)).Select(entry => entry.Seat));

        harness = Gathering();
        harness.Message(3, ReadyBody("member=3;pal"), ("duel", "ready"), ("bid", "b1"));
        harness.Leave(2);
        harness.Clear();
        harness.Frames(DuelHandshake.ReadyFrames + 1);

        Assert.Empty(harness.Starts);
        Assert.Equal(["Nobody of Friend's side was ready, the duel is off."], harness.Notices);
        Assert.Equal([3, 2], harness.Sent.Select(entry => entry.Seat));
    }

    /// <summary>
    /// Asserts that a challenge accepted before the world changed is forgotten, so the challenger's
    /// start that comes after is called off and nothing waits to start.
    /// </summary>
    [Fact]
    public void Challenge_GoesStaleAfterAWorldChange()
    {
        DuelHarness harness = Friend(("challenge", "1"));
        harness.Accept(2);
        harness.InWorld = false;
        harness.Frames();
        harness.InWorld = true;
        harness.Clear();
        harness.Message(2, DuelHarness.TeamBody(FriendTeam), ("duel", "start"), ("bid", "z1"));

        Assert.Equal([(2, "duel=cancel\nbid=z1\nreason=busy\n\n"), (2, "battle=broken\nbid=z1\n\n")], harness.Sent);
        Assert.Null(harness.Duel.PendingBattleId);
        Assert.Null(harness.Duel.View().Doing);
    }

    /// <summary>
    /// Asserts that while the scripts read an accept's team, a second accept finds the challenge
    /// taken, and that the first starts once they answered.
    /// </summary>
    [Fact]
    public void Accept_TakesNoOtherWhileItsTeamIsRead()
    {
        DuelHarness harness = Friend();
        harness.Tell(3, ("id", "pal"), ("name", "Pal"), ("map", "5"), ("x", "3"), ("y", "5"));
        harness.HoldNeeds = true;
        harness.Duel.Invite(null, false);
        Accepted(harness);
        harness.Message(3, DuelHarness.TeamBody("member=3;pal"), ("duel", "accept"));

        Assert.Equal([(3, "duel=decline\nreason=gone\n\n")], harness.Sent);
        harness.Clear();
        harness.Answer(Assert.Single(harness.Held));

        Assert.Equal(2, Assert.Single(harness.Sent).Seat);
        Assert.Equal("host", Assert.Single(harness.Starts).Role);
    }

    /// <summary>
    /// Asserts that a call-off while the scripts read the challenger's team drops the duel, so their
    /// late answer starts nothing.
    /// </summary>
    [Fact]
    public void Start_CalledOffWhileItsTeamIsRead_StartsNothing()
    {
        DuelHarness harness = Friend(("challenge", "1"));
        harness.Accept(2);
        harness.HoldNeeds = true;
        harness.Message(2, DuelHarness.TeamBody(FriendTeam), ("duel", "start"), ("bid", "x1"));
        harness.Message(2, string.Empty, ("duel", "cancel"), ("bid", "x1"), ("reason", "off"));
        harness.Answer(Assert.Single(harness.Held));

        Assert.Empty(harness.Starts);
        Assert.Equal("Friend called the duel off.", harness.Notices.Last());
    }

    /// <summary>
    /// Makes a world with Friend standing next to the player in seat 2.
    /// </summary>
    /// <param name="more">More fields of Friend's state.</param>
    /// <returns>The world.</returns>
    private static DuelHarness Friend(params (string Key, string Value)[] more)
    {
        var harness = new DuelHarness();
        harness.Tell(2, [("id", "friend"), ("name", "Friend"), ("map", "5"), ("x", "4"), ("y", "4"), .. more]);
        return harness;
    }

    /// <summary>
    /// Makes a world where the player leads a party with Pal and gathers a team duel Friend accepted.
    /// </summary>
    /// <returns>The world, its messages so far forgotten.</returns>
    private static DuelHarness Gathering()
    {
        DuelHarness harness = Friend();
        harness.Tell(3, ("id", "pal"), ("name", "Pal"), ("map", "5"), ("x", "30"), ("y", "30"), ("party", "me-p"));
        harness.Party("me-p", [3], -1);
        harness.Duel.Invite(null, false);
        Accepted(harness);
        harness.Clear();
        return harness;
    }

    /// <summary>
    /// Lets Friend accept the player's challenge.
    /// </summary>
    /// <param name="harness">The world.</param>
    /// <param name="body">Their game's fingerprint and team.</param>
    private static void Accepted(DuelHarness harness, string? body = null) =>
        harness.Message(2, body ?? DuelHarness.TeamBody(FriendTeam), ("duel", "accept"));

    /// <summary>
    /// Writes a called player's answer that they are ready.
    /// </summary>
    /// <param name="builds">Their Frontline.</param>
    /// <returns>The body.</returns>
    private static string ReadyBody(string builds) => WireWriter.Line(new WireString("game-1"), new WireString(builds), new WireInteger(8));
}
