//----------------------------------------------------------------
//  WorldTrades.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Started its threads through Threads and read who plays through Player.Current, both shared with the world's other parts
//                            - Cancelled a trade from its commit once the commit arrived, so a cancel that overtakes the commit still ends it
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// Trades between two players of a world as the game script uses them: committing one trade at a
/// time with the relay until both sides committed or it ended, cancelling, marking a trade done once
/// applied and saved, and fetching the committed trades not yet done, for recovery. Each runs on a
/// thread of its own, and the game script reads how the commit and the fetch stand.
/// </summary>
/// <remarks>
/// The offers are sealed with a key from the token of the world the game is in, so only games
/// that hold the token read them; the relay only compares their hashes.
/// </remarks>
internal sealed class WorldTrades
{
    /// <summary>
    /// What the game script reads as the state of the commit or the fetch.
    /// </summary>
    private const string StateHeader = "state";

    /// <summary>
    /// The trade the commit is about.
    /// </summary>
    private const string TradeHeader = "trade";

    /// <summary>
    /// Why the trade was cancelled.
    /// </summary>
    private const string ReasonHeader = "reason";

    /// <summary>
    /// Why the commit or the fetch failed.
    /// </summary>
    private const string ErrorHeader = "error";

    /// <summary>
    /// The relay's state of a trade only one side committed.
    /// </summary>
    private const string Pending = "pending";

    /// <summary>
    /// The relay's state of a trade both sides committed with the same offers, which both games apply.
    /// </summary>
    private const string Committed = "committed";

    /// <summary>
    /// The relay's state of a trade that ended without a swap.
    /// </summary>
    private const string Cancelled = "cancelled";

    /// <summary>
    /// Why a request failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// Why the commit failed when the relay never settled the trade.
    /// </summary>
    private const string NoAnswer = "The relay did not settle the trade in time.";

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// Counts the commits, so a thread of an earlier one changes nothing.
    /// </summary>
    private int _commitGeneration;

    /// <summary>
    /// The running or last commit, <see langword="null"/> before the first.
    /// </summary>
    private CommitState? _commit;

    /// <summary>
    /// The trade of the running commit that the game script asked to cancel, <see langword="null"/> while it did not.
    /// </summary>
    private string? _cancelWanted;

    /// <summary>
    /// Whether the committed trades not yet done are being fetched.
    /// </summary>
    private bool _fetching;

    /// <summary>
    /// Why the last fetch failed.
    /// </summary>
    private string? _fetchError;

    /// <summary>
    /// The committed trades not yet done as last fetched, each with its offers; <see langword="null"/> before the first fetch.
    /// </summary>
    private IReadOnlyList<(string Id, string Offers)>? _pending;

    /// <summary>
    /// The game's trades, which the game script uses.
    /// </summary>
    public static WorldTrades Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// Finds the world the game is in by its id, whose token seals the offers; tests hand out their own.
    /// </summary>
    public Func<string, WorldCode?> WorldOf { get; init; } = id => WorldSession.Current.OpenWorld(id);

    /// <summary>
    /// How often a commit asks the relay how the trade stands.
    /// </summary>
    public TimeSpan PollInterval { get; init; } = TimeSpan.FromSeconds(1);

    /// <summary>
    /// How long a commit waits for the relay to settle the trade, a little longer than the relay keeps it pending.
    /// </summary>
    public TimeSpan GiveUpAfter { get; init; } = TimeSpan.FromSeconds(150);

    /// <summary>
    /// How long a cancel or a done waits before each new try after the relay could not be reached.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10)];

    /// <summary>
    /// Commits this game's side of a trade and follows it until both sides committed or it ended,
    /// replacing whatever commit ran before.
    /// </summary>
    /// <param name="world">The world both players are in.</param>
    /// <param name="trade">The trade's id, the same in both games.</param>
    /// <param name="partner">The other player's id.</param>
    /// <param name="offers">The offers both games agreed on, the same text in both, on one line without tabs.</param>
    /// <returns><see langword="false"/> without a player, outside that world, or for offers that are empty, too long or not on one line.</returns>
    public bool Commit(string world, string trade, string partner, string offers)
    {
        if (!IsOneField(offers) || offers.Length == 0 || Encoding.UTF8.GetByteCount(offers) > TradeSeal.MaxOffersBytes)
        {
            Log.Write($"trade {trade} not committed: the offers are empty, too long or not on one line");
            return false;
        }

        if (Playing() is not { } player || WorldOf(world) is not { } code || RelayAddress(code.Relay) is not { } relay)
        {
            Log.Write($"trade {trade} not committed: no player, or not in world {world}");
            return false;
        }

        int generation;

        lock (_gate)
        {
            generation = ++_commitGeneration;
            _commit = new CommitState(trade, "sending");
            _cancelWanted = null;
        }

        var client = new DirectoryClient(relay);
        Threads.Start("MultiplayerTradeCommit", () => RunCommit(generation, client, new TradeCommit(world, trade, partner, offers, player.Key, code.Token)));
        return true;
    }

    /// <summary>
    /// Cancels a trade while the relay still holds it pending; how it went is only logged, and the
    /// commit learns the outcome from the relay.
    /// </summary>
    /// <remarks>
    /// The running commit of the trade cancels it again once its commit arrived, since this cancel may reach the relay first and find no trade.
    /// </remarks>
    /// <param name="world">The world both players are in.</param>
    /// <param name="trade">The trade's id.</param>
    /// <returns><see langword="false"/> without a player or a relay.</returns>
    public bool Cancel(string world, string trade)
    {
        if (Playing() is not { } player || ClientFor(world) is not { } client)
        {
            return false;
        }

        lock (_gate)
        {
            if (_commit?.Trade == trade)
            {
                _cancelWanted = trade;
            }
        }

        Threads.Start("MultiplayerTradeCancel", () => Retry($"cancelling trade {trade}", () =>
        {
            var answer = client.CancelTrade(trade, player.Key);
            Log.Write($"cancelled trade {trade}: {answer.State}");
        }));
        return true;
    }

    /// <summary>
    /// Marks a committed trade done for this player, whose game applied and saved it; how it went is only logged.
    /// </summary>
    /// <param name="world">The world both players are in.</param>
    /// <param name="trade">The trade's id.</param>
    /// <returns><see langword="false"/> without a player or a relay.</returns>
    public bool Done(string world, string trade)
    {
        if (Playing() is not { } player || ClientFor(world) is not { } client)
        {
            return false;
        }

        Threads.Start("MultiplayerTradeDone", () => Retry($"marking trade {trade} done", () =>
        {
            try
            {
                client.TradeDone(trade, player.Key);
                Log.Write($"marked trade {trade} done");
            }
            catch (DirectoryException ex) when (ex.Status == HttpStatusCode.NotFound)
            {
                // The relay deletes a trade once both games marked it done, so a repeated done finds none.
                Log.Write($"trade {trade} is gone from the relay, done already");
            }
        }));
        return true;
    }

    /// <summary>
    /// Fetches the committed trades of a world this player has not marked done, and unseals their offers.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <returns><see langword="false"/> while a fetch runs, without a player, or outside that world.</returns>
    public bool FetchPending(string world)
    {
        if (Playing() is not { } player || WorldOf(world) is not { } code || RelayAddress(code.Relay) is not { } relay)
        {
            return false;
        }

        lock (_gate)
        {
            if (_fetching)
            {
                return false;
            }

            _fetching = true;
        }

        var client = new DirectoryClient(relay);
        Threads.Start("MultiplayerTradePending", () =>
        {
            List<(string Id, string Offers)>? trades = null;
            string? error = null;

            try
            {
                trades = Unseal(client.PendingTrades(player.Key, world), code.Token);
                Log.Write($"fetched {trades.Count} committed trade(s) not yet done in world {world}");
            }
            catch (Exception ex)
            {
                error = ReasonFor(ex);
                Log.Write($"fetching the trades not yet done failed: {ex.GetBaseException().Message}");
            }

            lock (_gate)
            {
                _fetching = false;
                _fetchError = error;

                if (trades != null)
                {
                    _pending = trades;
                }
            }
        });
        return true;
    }

    /// <summary>
    /// Describes the running or last commit for the game script.
    /// </summary>
    /// <returns>Empty before the first commit; else <c>trade</c>, <c>state</c> ("sending", "waiting", "committed", "cancelled" or "failed"), and <c>reason</c> ("cancelled", "differ" or "expired") for a cancelled trade or <c>error</c> for a failed commit.</returns>
    public string DescribeCommit()
    {
        lock (_gate)
        {
            if (_commit is not { } commit)
            {
                return string.Empty;
            }

            var headers = new KeyValuePair<string, string?>[]
            {
                new(TradeHeader, commit.Trade),
                new(StateHeader, commit.State),
                new(ReasonHeader, commit.Reason),
                new(ErrorHeader, commit.Error),
            };

            return new Message(headers).Encode();
        }
    }

    /// <summary>
    /// Describes the last fetch of the committed trades not yet done for the game script.
    /// </summary>
    /// <returns>Empty before the first fetch; else <c>state</c> ("busy", "failed" or "done"), <c>error</c> when failed, and once done one line per trade: <c>trade=</c>, its id, a tab and its offers.</returns>
    public string DescribePending()
    {
        lock (_gate)
        {
            if (_fetching)
            {
                return new Message([new(StateHeader, "busy")]).Encode();
            }

            if (_fetchError != null)
            {
                return new Message([new(StateHeader, "failed"), new(ErrorHeader, _fetchError)]).Encode();
            }

            if (_pending == null)
            {
                return string.Empty;
            }

            var lines = new StringBuilder();

            foreach (var (id, offers) in _pending)
            {
                lines.Append(TradeHeader).Append('=').Append(id).Append('\t').Append(offers).Append('\n');
            }

            return new Message([new(StateHeader, "done")], lines.ToString()).Encode();
        }
    }

    /// <summary>
    /// Sends a commit and asks how the trade stands about once a second, until the relay committed
    /// or cancelled it, a newer commit replaced this one, or the time is up.
    /// </summary>
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game. The
    /// commit is sent again until one arrives, which the relay takes as the same commit.
    /// </remarks>
    /// <param name="generation">The commit this thread belongs to.</param>
    /// <param name="client">The relay's client.</param>
    /// <param name="commit">What is committed.</param>
    private void RunCommit(int generation, DirectoryClient client, TradeCommit commit)
    {
        try
        {
            var hash = TradeSeal.HashOf(commit.Offers);
            var sealedOffers = TradeSeal.Seal(commit.Token, commit.Trade, commit.Offers);
            var deadline = DateTime.UtcNow + GiveUpAfter;
            var arrived = false;
            var reached = false;
            var cancelSent = false;

            while (IsCurrent(generation))
            {
                try
                {
                    var answer = arrived ? client.TradeState(commit.Trade, commit.PlayerKey) : client.CommitTrade(commit.Trade, commit.PlayerKey, commit.World, commit.Partner, hash, sealedOffers);

                    if (!arrived)
                    {
                        Log.Write($"committed trade {commit.Trade} with {commit.Partner}: {answer.State}");
                    }

                    arrived = true;
                    reached = true;

                    if (answer.State == Pending && !cancelSent && IsCancelWanted(commit.Trade))
                    {
                        answer = client.CancelTrade(commit.Trade, commit.PlayerKey);
                        cancelSent = true;
                        Log.Write($"cancelled trade {commit.Trade} once its commit arrived: {answer.State}");
                    }

                    if (answer.State is Committed or Cancelled)
                    {
                        Log.Write($"trade {commit.Trade} {answer.State}{(answer.Reason.Length > 0 ? $" ({answer.Reason})" : string.Empty)}");
                        Settle(generation, commit.Trade, answer.State, answer.Reason, null);
                        return;
                    }

                    if (answer.State != Pending)
                    {
                        throw new InvalidDataException($"The relay answered the state {answer.State}.");
                    }

                    Settle(generation, commit.Trade, "waiting", null, null);
                }
                catch (DirectoryException ex) when (ex.Status == null)
                {
                    // Lost on the way, so the game tries again until the time is up.
                    Log.Write($"trade {commit.Trade}: {ex.Message}");
                }

                if (DateTime.UtcNow >= deadline)
                {
                    Log.Write($"trade {commit.Trade} failed: the relay never settled it");
                    Settle(generation, commit.Trade, "failed", null, reached ? NoAnswer : Unreachable);
                    return;
                }

                Thread.Sleep(PollInterval);
            }
        }
        catch (Exception ex)
        {
            Log.Write($"trade {commit.Trade} failed: {ex.GetBaseException().Message}");
            Settle(generation, commit.Trade, "failed", null, ReasonFor(ex));
        }
    }

    /// <summary>
    /// Notes how a commit stands, unless a newer one replaced it.
    /// </summary>
    /// <param name="generation">The commit.</param>
    /// <param name="trade">The trade's id.</param>
    /// <param name="state">The state the game script reads.</param>
    /// <param name="reason">Why the trade was cancelled, or <see langword="null"/>.</param>
    /// <param name="error">Why the commit failed, or <see langword="null"/>.</param>
    private void Settle(int generation, string trade, string state, string? reason, string? error)
    {
        lock (_gate)
        {
            if (generation == _commitGeneration)
            {
                _commit = new CommitState(trade, state, reason is { Length: > 0 } ? reason : null, error);
            }
        }
    }

    /// <summary>
    /// Reports whether a commit is still the current one.
    /// </summary>
    /// <param name="generation">The commit.</param>
    /// <returns><see langword="true"/> while it is.</returns>
    private bool IsCurrent(int generation)
    {
        lock (_gate)
        {
            return generation == _commitGeneration;
        }
    }

    /// <summary>
    /// Reports whether the game script asked to cancel a trade while its commit ran.
    /// </summary>
    /// <param name="trade">The trade's id.</param>
    /// <returns><see langword="true"/> when it did.</returns>
    private bool IsCancelWanted(string trade)
    {
        lock (_gate)
        {
            return _cancelWanted == trade;
        }
    }

    /// <summary>
    /// Unseals the offers of fetched trades, leaving out and logging any that do not open or whose hash differs.
    /// </summary>
    /// <param name="trades">The trades as the relay keeps them.</param>
    /// <param name="token">The world's token.</param>
    /// <returns>Each trade's id and offers.</returns>
    private static List<(string Id, string Offers)> Unseal(IReadOnlyList<SealedTrade> trades, string token)
    {
        var opened = new List<(string Id, string Offers)>();

        foreach (var trade in trades)
        {
            try
            {
                var offers = TradeSeal.Open(token, trade.Id, trade.Sealed);

                if (TradeSeal.HashOf(offers) != trade.Hash || !IsOneField(offers) || !IsOneField(trade.Id))
                {
                    throw new InvalidDataException("The offers do not match their hash.");
                }

                opened.Add((trade.Id, offers));
            }
            catch (InvalidDataException ex)
            {
                Log.Write($"left out trade {trade.Id}: {ex.Message}");
            }
        }

        return opened;
    }

    /// <summary>
    /// Runs a request, again after each of the retry delays while the relay cannot be reached; how it went is only logged.
    /// </summary>
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="what">What the request does, for the log.</param>
    /// <param name="request">The request.</param>
    private void Retry(string what, Action request)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                request();
                return;
            }
            catch (DirectoryException ex) when (ex.Status == null && attempt < RetryDelays.Length)
            {
                Log.Write($"{what} failed, trying again: {ex.Message}");
                Thread.Sleep(RetryDelays[attempt]);
            }
            catch (Exception ex)
            {
                Log.Write($"{what} failed: {ex.GetBaseException().Message}");
                return;
            }
        }
    }

    /// <summary>
    /// Makes a client for the relay of the world the game is in, or of this version's relay once it left.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <returns>The client, or <see langword="null"/> for a relay this version does not know.</returns>
    private DirectoryClient? ClientFor(string world) =>
        RelayAddress(WorldOf(world)?.Relay ?? Relays.Current) is { } relay ? new DirectoryClient(relay) : null;

    /// <summary>
    /// Tells whether a text stays inside one field of a line the game script reads.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it holds no tab and no line break.</returns>
    private static bool IsOneField(string text) => text.IndexOfAny(['\t', '\r', '\n']) < 0;

    /// <summary>
    /// Tells the player why a request failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(Exception ex) => ex switch
    {
        DirectoryException { Status: null } => Unreachable,
        DirectoryException { Status: HttpStatusCode.Forbidden } => "Both players must be players of this world.",
        DirectoryException { Status: HttpStatusCode.NotFound } => "The relay knows no such world or trade.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests } => "You have too many open trades. Finish one first.",
        DirectoryException directory => $"The relay refused: {directory.Message}",
        InvalidDataException data => data.Message,
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// How a commit stands, as the game script reads it.
    /// </summary>
    /// <param name="Trade">The trade's id.</param>
    /// <param name="State">"sending", "waiting", "committed", "cancelled" or "failed".</param>
    /// <param name="Reason">Why the trade was cancelled, or <see langword="null"/>.</param>
    /// <param name="Error">Why the commit failed, or <see langword="null"/>.</param>
    private sealed record CommitState(string Trade, string State, string? Reason = null, string? Error = null);

    /// <summary>
    /// What a commit sends.
    /// </summary>
    /// <param name="World">The world both players are in.</param>
    /// <param name="Trade">The trade's id.</param>
    /// <param name="Partner">The other player's id.</param>
    /// <param name="Offers">The offers both games agreed on.</param>
    /// <param name="PlayerKey">This player's key.</param>
    /// <param name="Token">The world's token, which seals the offers.</param>
    private sealed record TradeCommit(string World, string Trade, string Partner, string Offers, string PlayerKey, string Token);
}
