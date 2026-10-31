//----------------------------------------------------------------
//  GatherTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Stopped carrying the warp ban along with a call, a follow or an offer
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Telling;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a story's calls (<see cref="GatherCalls"/>), which both hosts answer
/// through <see cref="SharedTopics"/>, since coop_gather.rbx loads on the battle server too. Every
/// frame is the context's. A place is [map, x, y, d].
/// </summary>
public static class GatherTopics
{
    /// <summary>
    /// Takes a leader's call: <c>name</c>, <c>id</c>, <c>place</c>, <c>near</c> and <c>pvp</c> in;
    /// <c>notice</c> (what the player reads, or nil) out.
    /// </summary>
    public const string Called = "gather.called";

    /// <summary>
    /// Takes a teleport the player asked for: <c>name</c> and <c>place</c> in.
    /// </summary>
    public const string ComeTo = "gather.come_to";

    /// <summary>
    /// Takes a teller's follow: <c>name</c>, <c>id</c>, <c>place</c> and <c>raid</c> in.
    /// </summary>
    public const string Followed = "gather.followed";

    /// <summary>
    /// Keeps a ban of the place for the arrival: <c>id</c> (the switch), <c>on</c> and <c>map</c>
    /// in; whether a call to that map keeps it out.
    /// </summary>
    public const string Ban = "gather.ban";

    /// <summary>
    /// Reads the call as the frame stands: <c>settled</c>, <c>leading</c> (whether the player leads
    /// the party) and <c>missing</c> (the names of those not near while the player holds a scene)
    /// in; <c>coming</c>, <c>pending</c> ({<c>name</c>, <c>id</c>, <c>place</c>, <c>since</c>,
    /// <c>follow</c>, <c>asked</c>} or nil), <c>notice</c> (what the player reads
    /// once the call lapsed, or nil), <c>come</c> (the place to come to, or nil), <c>waited</c>
    /// (whether the player waited the frames a call gives them), <c>follow</c> ({<c>id</c>,
    /// <c>name</c>, <c>place</c>} or nil), <c>holding</c>, <c>doing</c> ({<c>text</c>,
    /// <c>left</c> (frames, or nil)} or nil) and <c>idle</c> (whether nothing stands, see
    /// <see cref="GatherCalls.Idle"/>) out.
    /// </summary>
    public const string Frame = "gather.frame";

    /// <summary>
    /// Takes the call the player answers now: <c>raid</c> in; {<c>name</c>, <c>id</c>, <c>place</c>,
    /// <c>follow</c>, <c>asked</c>, <c>bans</c> ([switch, on] each)} or nil out.
    /// </summary>
    public const string Take = "gather.take";

    /// <summary>
    /// Reports whether a battle belongs to the story that calls the player: <c>id</c> and <c>map</c> in.
    /// </summary>
    public const string CallingBattle = "gather.calling_battle";

    /// <summary>
    /// Forgets the call: the call's name or nil out.
    /// </summary>
    public const string DropCall = "gather.drop_call";

    /// <summary>
    /// Holds a story scene the leader starts.
    /// </summary>
    public const string Hold = "gather.hold";

    /// <summary>
    /// Forgets the scene held: whether one was out.
    /// </summary>
    public const string DropHold = "gather.drop_hold";

    /// <summary>
    /// Tells whether the scene held still waits before a command: <c>leading</c>, <c>gathered</c>
    /// and <c>missing</c> in; <c>wait</c>, <c>call_again</c>, <c>notice</c> and <c>released</c> out.
    /// </summary>
    public const string Holding = "gather.holding";

    /// <summary>
    /// Offers a follow: <c>id</c>, <c>name</c> and <c>place</c> in.
    /// </summary>
    public const string Offer = "gather.offer";

    /// <summary>
    /// Finds a standing offer: <c>id</c>, <c>telling</c> and <c>map</c> in; {<c>name</c>,
    /// <c>place</c>, <c>since</c>} while it stands, {<c>dropped</c>} once it
    /// ended, nil for none out.
    /// </summary>
    public const string FollowOffer = "gather.follow_offer";

    /// <summary>
    /// Takes an offer the player accepted: as <see cref="FollowOffer"/> in; the offer or nil out.
    /// </summary>
    public const string Accept = "gather.accept";

    /// <summary>
    /// Drops an offer the player declined: <c>id</c> in; the teller's name or nil out.
    /// </summary>
    public const string Decline = "gather.decline";

    /// <summary>
    /// Forgets the call, the follow taken and the hold: <c>held</c> and <c>call</c> (the name, or nil) out.
    /// </summary>
    public const string Forget = "gather.forget";

    /// <summary>
    /// Forgets the offers.
    /// </summary>
    public const string ForgetOffers = "gather.forget_offers";

    /// <summary>
    /// Registers the topics on a context, over calls of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var calls = new GatherCalls();
        context.Register(Called, (host, request) => CalledOf(calls, request.AsHash(), host.Frame));
        context.Register(ComeTo, (host, request) =>
        {
            RubyHash fields = request.AsHash();
            calls.ComeTo(fields["name"].AsText(), PlaceOf(fields["place"]), host.Frame);
            return null;
        });
        context.Register(Followed, (host, request) =>
        {
            RubyHash fields = request.AsHash();
            calls.Followed(fields["name"].AsText(), fields["id"].AsText(), PlaceOf(fields["place"]), fields["raid"].AsBool(), host.Frame);
            return null;
        });
        context.Register(Ban, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            return calls.KeepBan(fields["id"].AsInt(), fields["on"].AsBool(), fields["map"].AsInt());
        });
        context.Register(Frame, (host, request) => FrameOf(calls, request.AsHash(), host.Frame));
        context.Register(Take, (host, request) => TakeOf(calls, request.AsHash()["raid"].AsBool(), host.Frame));
        context.Register(CallingBattle, (host, request) =>
        {
            RubyHash fields = request.AsHash();
            return calls.CallingBattle(fields["id"].AsText(), fields["map"].AsInt(), host.Frame);
        });
        context.Register(DropCall, (_, _) => calls.DropCall() is { } name ? name : RubyNil.Value);
        context.Register(Hold, (host, _) =>
        {
            calls.Hold(host.Frame);
            return null;
        });
        context.Register(DropHold, (_, _) => calls.DropHold());
        context.Register(Holding, (host, request) => HoldingOf(calls, request.AsHash(), host.Frame));
        context.Register(Offer, (host, request) =>
        {
            RubyHash fields = request.AsHash();
            calls.OfferFollow(fields["id"].AsText(), fields["name"].AsText(), PlaceOf(fields["place"]), host.Frame);
            return null;
        });
        context.Register(FollowOffer, (host, request) => FollowOfferOf(calls, request.AsHash(), host.Frame, false));
        context.Register(Accept, (host, request) => FollowOfferOf(calls, request.AsHash(), host.Frame, true));
        context.Register(Decline, (_, request) => calls.DeclineFollow(request.AsHash()["id"].AsText()) is { } name ? name : RubyNil.Value);
        context.Register(Forget, (_, _) =>
        {
            (bool held, string? name) = calls.Forget();
            return new RubyHash { { "held", held }, { "call", name is null ? RubyNil.Value : name } };
        });
        context.Register(ForgetOffers, (_, _) =>
        {
            calls.ForgetOffers();
            return null;
        });
    }

    /// <summary>
    /// Answers <see cref="Called"/>.
    /// </summary>
    /// <param name="calls">The calls.</param>
    /// <param name="fields">The request.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>The notice, or nil.</returns>
    private static RubyHash CalledOf(GatherCalls calls, RubyHash fields, long frame)
    {
        string? notice = calls.Called(fields["name"].AsText(), fields["id"].AsText(), PlaceOf(fields["place"]), fields["near"].AsBool(), fields["pvp"].AsBool(), frame);
        return new RubyHash { { "notice", notice is null ? RubyNil.Value : notice } };
    }

    /// <summary>
    /// Answers <see cref="Frame"/>.
    /// </summary>
    /// <param name="calls">The calls.</param>
    /// <param name="fields">The request.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>The call as the frame stands.</returns>
    private static RubyHash FrameOf(GatherCalls calls, RubyHash fields, long frame)
    {
        GatherCall? pending = calls.Pending(frame, out string? notice);
        GatherFollow? follow = calls.FollowTaken(frame);
        GatherDoing? doing = calls.OwnDoing(fields["leading"].AsBool(), Texts(fields["missing"]), frame);
        return new RubyHash
        {
            { "coming", calls.Coming(frame) },
            { "pending", pending is null ? RubyNil.Value : new RubyHash
                {
                    { "name", pending.Name }, { "id", pending.Id is null ? RubyNil.Value : pending.Id }, { "place", PlaceNode(pending.Place) }, { "since", pending.Since },
                    { "follow", pending.Follow }, { "asked", pending.Asked },
                } },
            { "notice", notice is null ? RubyNil.Value : notice },
            { "come", calls.Come(frame, fields["settled"].AsBool()) is { } place ? PlaceNode(place) : RubyNil.Value },
            { "waited", calls.Waited(frame) },
            { "follow", follow is null ? RubyNil.Value : new RubyHash { { "id", follow.Id }, { "name", follow.Name }, { "place", PlaceNode(follow.Place) } } },
            { "holding", calls.HoldingStory },
            { "doing", doing is null ? RubyNil.Value : new RubyHash { { "text", doing.Text }, { "left", doing.FramesLeft is { } left ? left : RubyNil.Value } } },
            { "idle", calls.Idle(frame) },
        };
    }

    /// <summary>
    /// Answers <see cref="Take"/>.
    /// </summary>
    /// <param name="calls">The calls.</param>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>The call taken, or nil.</returns>
    private static RubyValue TakeOf(GatherCalls calls, bool raid, long frame)
    {
        if (calls.Take(raid, frame) is not { } taken)
        {
            return RubyNil.Value;
        }

        return new RubyHash
        {
            { "name", taken.Call.Name }, { "id", taken.Call.Id is null ? RubyNil.Value : taken.Call.Id }, { "place", PlaceNode(taken.Call.Place) },
            { "follow", taken.Call.Follow }, { "asked", taken.Call.Asked },
            { "bans", new RubyArray(taken.Bans.OrderBy(pair => pair.Key).Select(pair => (RubyValue)new RubyArray { pair.Key, pair.Value })) },
        };
    }

    /// <summary>
    /// Answers <see cref="Holding"/>.
    /// </summary>
    /// <param name="calls">The calls.</param>
    /// <param name="fields">The request.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>What the scene does.</returns>
    private static RubyHash HoldingOf(GatherCalls calls, RubyHash fields, long frame)
    {
        HoldStep step = calls.Holding(fields["leading"].AsBool(), fields["gathered"].AsBool(), Texts(fields["missing"]), frame);
        return new RubyHash
        {
            { "wait", step.Wait }, { "call_again", step.CallAgain }, { "notice", step.Notice is null ? RubyNil.Value : step.Notice }, { "released", step.Released is null ? RubyNil.Value : step.Released },
        };
    }

    /// <summary>
    /// Answers <see cref="FollowOffer"/> and <see cref="Accept"/>.
    /// </summary>
    /// <param name="calls">The calls.</param>
    /// <param name="fields">The request.</param>
    /// <param name="frame">The frame.</param>
    /// <param name="accept">Whether the player accepted the offer, which takes it.</param>
    /// <returns>The offer, why it ended, or nil.</returns>
    private static RubyValue FollowOfferOf(GatherCalls calls, RubyHash fields, long frame, bool accept)
    {
        string id = fields["id"].AsText();
        bool telling = fields["telling"].AsBool();
        int map = fields["map"].AsInt();
        string? dropped = null;
        GatherOffer? offer = accept ? calls.AcceptFollow(id, telling, map, frame) : calls.FollowOffer(id, telling, map, frame, out dropped);
        if (offer is not null)
        {
            return new RubyHash { { "name", offer.Name }, { "place", PlaceNode(offer.Place) }, { "since", offer.Since } };
        }

        return dropped is null ? RubyNil.Value : new RubyHash { { "dropped", dropped } };
    }

    /// <summary>
    /// Reads a place.
    /// </summary>
    /// <param name="value">[map, x, y, d].</param>
    /// <returns>The place.</returns>
    /// <exception cref="BridgeRequestException">The place is no four numbers.</exception>
    private static GatherPlace PlaceOf(RubyValue value)
    {
        RubyArray place = value.AsArray();
        if (place.Count != 4)
        {
            throw new BridgeRequestException("A place is [map, x, y, d].");
        }

        return new GatherPlace(place[0].AsInt(), place[1].AsInt(), place[2].AsInt(), place[3].AsInt());
    }

    /// <summary>
    /// Writes a place.
    /// </summary>
    /// <param name="place">The place.</param>
    /// <returns>[map, x, y, d].</returns>
    private static RubyArray PlaceNode(GatherPlace place) => new() { place.Map, place.X, place.Y, place.Direction };

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The texts.</returns>
    private static List<string> Texts(RubyValue list) => [.. list.AsArray().Select(item => item.AsText())];
}
