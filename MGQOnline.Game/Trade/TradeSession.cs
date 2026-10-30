//----------------------------------------------------------------
//  TradeSession.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Trade;

/// <summary>
/// Where a trade stands.
/// </summary>
public enum TradeStage
{
    /// <summary>
    /// Both players put the offers together.
    /// </summary>
    Open,

    /// <summary>
    /// The relay decides on the confirmed offers.
    /// </summary>
    Committing,

    /// <summary>
    /// The trade ended.
    /// </summary>
    Closed,
}

/// <summary>
/// A trade between the player and one other player: both offers as text, their revisions and the
/// confirmations.
/// </summary>
/// <param name="id">The trade's id, 24 hexadecimal characters, made by the player who offered it.</param>
/// <param name="partner">The other player's id.</param>
/// <param name="name">The other player's name.</param>
public sealed class TradeSession(string id, string partner, string name)
{
    /// <summary>
    /// Gets the trade's id.
    /// </summary>
    public string Id { get; } = id;

    /// <summary>
    /// Gets the other player's id.
    /// </summary>
    public string Partner { get; } = partner;

    /// <summary>
    /// Gets the other player's name.
    /// </summary>
    public string Name { get; } = name;

    /// <summary>
    /// Gets the player's offer as text, as the scripts wrote it last; an empty offer until they do.
    /// </summary>
    public string Mine { get; internal set; } = TradeOffers.Empty;

    /// <summary>
    /// Gets the other player's offer as text, as they sent it last; an empty offer until they do.
    /// </summary>
    public string Theirs { get; internal set; } = TradeOffers.Empty;

    /// <summary>
    /// Gets how often the player changed their offer.
    /// </summary>
    public long MyRevision { get; internal set; }

    /// <summary>
    /// Gets how often the other player changed theirs.
    /// </summary>
    public long TheirRevision { get; internal set; }

    /// <summary>
    /// Gets a value indicating whether the player confirmed both offers as they stand.
    /// </summary>
    public bool Confirmed { get; internal set; }

    /// <summary>
    /// Gets the revisions the other player confirmed, theirs then the player's; <see langword="null"/>
    /// while they confirmed none.
    /// </summary>
    public (long Theirs, long Mine)? TheirConfirm { get; internal set; }

    /// <summary>
    /// Gets where the trade stands.
    /// </summary>
    public TradeStage Stage { get; internal set; }

    /// <summary>
    /// Gets the frames the other player has been away.
    /// </summary>
    public int Away { get; internal set; }

    /// <summary>
    /// Gets the id the relay knows the confirmed offers by, <see langword="null"/> while none went to it.
    /// </summary>
    public string? RelayId { get; internal set; }

    /// <summary>
    /// Gets the notice the trade closes with once the relay cancelled the commit, set when a player
    /// cancelled while the relay decided; <see langword="null"/> while nobody did.
    /// </summary>
    public string? Leaving { get; internal set; }

    /// <summary>
    /// Gets the failed tries to send the player's offer and confirmation state again since a message
    /// to the other player could not go out; <see langword="null"/> while every message went out.
    /// </summary>
    public int? Unsent { get; internal set; }

    /// <summary>
    /// Gets a value indicating whether the other player confirmed the offers as they stand now.
    /// </summary>
    public bool TheirConfirmed => TheirConfirm == (TheirRevision, MyRevision);

    /// <summary>
    /// Gets a value indicating whether both players confirmed the offers as they stand now.
    /// </summary>
    public bool Agreed => Confirmed && TheirConfirmed;

    /// <summary>
    /// Gets the stage as the log and the scripts name it.
    /// </summary>
    public string StageName => Stage switch
    {
        TradeStage.Open => "open",
        TradeStage.Committing => "committing",
        _ => "closed",
    };
}
