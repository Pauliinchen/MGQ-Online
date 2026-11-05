//----------------------------------------------------------------
//  BattlerTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Setup;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topic of the battlers the scripts build, see <see cref="BattlerSetup"/>, which both
/// hosts answer through <see cref="SharedTopics"/>.
/// </summary>
public static class BattlerTopics
{
    /// <summary>
    /// Plans a battler: <c>kind</c> (<c>ally</c>, <c>enemy</c> or <c>reserve</c>), <c>started</c>, <c>vitals</c>
    /// (the HP and MP an owner sent, or nil) and <c>mark</c> in; <c>hp</c>, <c>mp</c> (each nil
    /// for the build's full), <c>start</c>, <c>hide</c> and <c>lay_down</c> out.
    /// </summary>
    public const string PlanTopic = "battlers.plan";

    /// <summary>
    /// Registers the topic on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(PlanTopic, (_, request) => PlanOf(request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="PlanTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The plan.</returns>
    private static RubyHash PlanOf(RubyHash request)
    {
        RubyArray? vitals = request["vitals"] as RubyArray;
        var order = new BattlerOrder(KindOf(request["kind"].AsText()), request["started"] is RubyBool { Flag: true },
            vitals is { Count: > 0 } ? Whole(vitals[0]) : null, vitals is { Count: > 1 } ? Whole(vitals[1]) : null, Whole(request["mark"]) ?? BattlerSetup.Shown);
        BattlerPlan plan = BattlerSetup.Plan(order);
        return new RubyHash
        {
            { "hp", plan.Hp is { } hp ? (RubyValue)hp : RubyNil.Value },
            { "mp", plan.Mp is { } mp ? (RubyValue)mp : RubyNil.Value },
            { "start", plan.Start },
            { "hide", plan.Hide },
            { "lay_down", plan.LayDown },
        };
    }

    /// <summary>
    /// Reads the kind of a battler the script names.
    /// </summary>
    /// <param name="kind">The name.</param>
    /// <returns>The kind, an enemy for any name but <c>ally</c> and <c>reserve</c>.</returns>
    private static BattlerKind KindOf(string? kind) => kind switch
    {
        "ally" => BattlerKind.Ally,
        "reserve" => BattlerKind.Reserve,
        _ => BattlerKind.Enemy,
    };

    /// <summary>
    /// Reads a whole number another game sent, which may be of any kind.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, <see langword="null"/> for one of another kind or past a long.</returns>
    private static long? Whole(RubyValue value) =>
        value is RubyInteger { Value: var number } && number >= long.MinValue && number <= long.MaxValue ? (long)number : null;
}
