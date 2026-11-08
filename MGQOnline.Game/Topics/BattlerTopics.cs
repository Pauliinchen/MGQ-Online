//----------------------------------------------------------------
//  BattlerTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Registered the topic of the steps that build another player's character
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Setup;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the battlers the scripts build, see <see cref="BattlerSetup"/>, which both
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
    /// Lists the steps that build another player's character, see <see cref="BattlerSetup.AllySteps"/>:
    /// <c>class</c> and <c>tribe</c> (nil for one this game lacks), <c>levels</c> ([id, level]
    /// pairs), <c>level</c>, <c>skills</c>, <c>abilities</c>, <c>equip_abilities</c>,
    /// <c>param_plus</c> and <c>slots</c> in; the steps out, each the changer's name
    /// (<c>class</c>, <c>job</c>, <c>race</c>, <c>classes</c>, <c>level</c>, <c>skills</c>, <c>param</c>, <c>abilities</c> or <c>equip</c>)
    /// followed by its values.
    /// </summary>
    public const string StepsTopic = "battlers.steps";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(PlanTopic, (_, request) => PlanOf(request.AsHash()));
        context.Register(StepsTopic, (_, request) => StepsOf(request.AsHash()));
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
    /// Answers <see cref="StepsTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The steps.</returns>
    private static RubyArray StepsOf(RubyHash request)
    {
        var build = new AllyBuild(
            request["class"].IsNil ? null : request["class"].AsLong(),
            request["tribe"].IsNil ? null : request["tribe"].AsLong(),
            [.. request["levels"].AsArray().Select(pair => (pair.AsArray()[0].AsLong(), pair.AsArray()[1].AsLong()))],
            request["level"].AsLong(),
            Wholes(request["skills"]),
            Wholes(request["abilities"]),
            Wholes(request["equip_abilities"]),
            Wholes(request["param_plus"]),
            request["slots"].AsInt());
        return new RubyArray(BattlerSetup.AllySteps(build).Select(step =>
            (RubyValue)new RubyArray(new[] { (RubyValue)ChangerName(step.Changer) }.Concat(step.Values.Select(value => (RubyValue)value)))));
    }

    /// <summary>
    /// Names a changer as the scripts take it.
    /// </summary>
    /// <param name="changer">The changer.</param>
    /// <returns>Its name.</returns>
    private static string ChangerName(AllyChanger changer) => changer switch
    {
        AllyChanger.Class => "class",
        AllyChanger.Job => "job",
        AllyChanger.Race => "race",
        AllyChanger.Classes => "classes",
        AllyChanger.Level => "level",
        AllyChanger.Skills => "skills",
        AllyChanger.Param => "param",
        AllyChanger.Abilities => "abilities",
        _ => "equip",
    };

    /// <summary>
    /// Reads a list of whole numbers.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The numbers.</returns>
    private static List<long> Wholes(RubyValue value) => [.. value.AsArray().Select(number => number.AsLong())];

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
