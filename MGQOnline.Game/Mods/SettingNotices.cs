//----------------------------------------------------------------
//  SettingNotices.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Mods;

/// <summary>
/// What the players are told of a world's shared mod settings, naming the options as this game's
/// Mod Config groups them.
/// </summary>
/// <param name="groups">The groups of this game's Mod Config, in its order.</param>
public sealed class SettingNotices(IReadOnlyList<SettingGroup> groups)
{
    /// <summary>
    /// What another player is told as they play in a world that shares settings, the creator's name
    /// and the options set filled in.
    /// </summary>
    public const string StayText = "{0} shares mod settings here: {1} set for you. Your own saves keep yours.";

    /// <summary>
    /// What another player is told instead when none of the settings are for their mods.
    /// </summary>
    public const string StayEmptyText = "{0} shares mod settings here, but none are set for your mods yet.";

    /// <summary>
    /// What the creator is told as they play in their world that shares settings, the mods filled in.
    /// </summary>
    public const string StayCreatorText = "You share your options of {0} with every player here.";

    /// <summary>
    /// What the creator is told instead when the world's mods have no options to share.
    /// </summary>
    public const string StayCreatorNoneText = "You share your mod settings here, but this world's mods have no options to share.";

    /// <summary>
    /// What another player is told once the world starts sharing settings.
    /// </summary>
    public const string NowSharedText = "{0} now shares mod settings: {1} set for you. Your own saves keep yours.";

    /// <summary>
    /// What another player is told instead when none of the settings are for their mods.
    /// </summary>
    public const string NowSharedEmptyText = "{0} now shares mod settings, but none are set for your mods yet.";

    /// <summary>
    /// What another player is told of a change, the creator's name and the changes filled in.
    /// </summary>
    public const string ChangedText = "{0} changed the shared mod settings: {1}.";

    /// <summary>
    /// What another player is told once the world stops sharing settings.
    /// </summary>
    public const string NoLongerText = "{0} stopped sharing mod settings: you can set your own options again. Your save here keeps the values so far.";

    /// <summary>
    /// What the creator is told once sharing is on, the mods filled in.
    /// </summary>
    public const string CreatorOnText = "Shared Mod Settings on: players here get your options of {0}.";

    /// <summary>
    /// What the creator is told instead when the world's mods have no options to share.
    /// </summary>
    public const string CreatorOnNoneText = "Shared Mod Settings on, but this world's mods have no options to share.";

    /// <summary>
    /// What the creator is told once sharing is off.
    /// </summary>
    public const string CreatorOffText = "Shared Mod Settings off: every player here sets their own mod options again.";

    /// <summary>
    /// What the creator is told of a change every player got.
    /// </summary>
    public const string CreatorChangeText = "Shared with every player: {0}.";

    /// <summary>
    /// What the creator is told when the relay refused the settings or never answered.
    /// </summary>
    public const string FailedText = "The world's mod settings could not be saved. Try again later.";

    /// <summary>
    /// What the creator is told, once, while settings cannot be sent.
    /// </summary>
    public const string NotSentText = "The world's mod settings could not be sent yet. Trying again in a moment.";

    /// <summary>
    /// What the creator is told first when options did not fit, how many filled in.
    /// </summary>
    public const string LeftOutText = "{0} option(s) could not be shared.";

    /// <summary>
    /// What the creator is told once the relay holds settings someone else set, the changes filled in.
    /// </summary>
    public const string RelayChangedText = "An admin changed the shared mod settings: {0}.";

    /// <summary>
    /// What the creator is told once sharing was turned on on the relay, the mods filled in.
    /// </summary>
    public const string RelayOnText = "An admin turned Shared Mod Settings on: players here get the options of {0}.";

    /// <summary>
    /// What the creator is told once sharing was turned off on the relay.
    /// </summary>
    public const string RelayOffText = "An admin turned Shared Mod Settings off: every player here sets their own mod options again.";

    /// <summary>
    /// Most mods a notice names before it counts the rest.
    /// </summary>
    public const int NamedMods = 2;

    /// <summary>
    /// Most changed options a notice names before it counts the rest.
    /// </summary>
    public const int NamedChanges = 2;

    /// <summary>
    /// Keeps the options this game's Mod Config has, which are the only ones a notice can name.
    /// </summary>
    /// <param name="keys">The options.</param>
    /// <returns>Those of them in a mod's group.</returns>
    public List<string> KnownKeys(IEnumerable<string> keys) => [.. keys.Where(key => OptionOf(key) != null)];

    /// <summary>
    /// Names the mods whose options some are.
    /// </summary>
    /// <param name="keys">The options.</param>
    /// <returns>Such as "Level Cap, Party Sheet and 2 more", "the world's mods" when none is known.</returns>
    public string ModsText(IReadOnlyCollection<string> keys)
    {
        List<string> names = [.. groups.Where(group => group.Options.Any(option => keys.Contains(option.Key))).Select(group => group.Name)];
        return names.Count == 0 ? "the world's mods" : SharedSettings.ListText(names, NamedMods);
    }

    /// <summary>
    /// Tells how many options of which mods a world sets.
    /// </summary>
    /// <param name="keys">The options, each in this game's Mod Config.</param>
    /// <returns>Such as "2 options of Level Cap are".</returns>
    public string OptionsText(IReadOnlyCollection<string> keys) =>
        keys.Count == 1 ? $"1 option of {ModsText(keys)} is" : $"{keys.Count.ToString(CultureInfo.InvariantCulture)} options of {ModsText(keys)} are";

    /// <summary>
    /// Tells another player what the world sets for them while they play in it.
    /// </summary>
    /// <param name="keys">The options set that this game's Mod Config has.</param>
    /// <param name="name">The creator's name.</param>
    /// <returns>The notice.</returns>
    public string Stay(IReadOnlyCollection<string> keys, string name) =>
        keys.Count == 0 ? Format(StayEmptyText, name) : Format(StayText, name, OptionsText(keys));

    /// <summary>
    /// Tells the creator what they share, and first how many options did not fit.
    /// </summary>
    /// <param name="settings">The settings the world has.</param>
    /// <param name="leftOut">How many options did not fit.</param>
    /// <returns>The notice.</returns>
    public string CreatorStay(string settings, int leftOut)
    {
        List<string> keys = KnownKeys(SharedSettings.Values(settings).Select(value => value.Key));
        string text = keys.Count == 0 ? StayCreatorNoneText : Format(StayCreatorText, ModsText(keys));
        return leftOut > 0 ? $"{Format(LeftOutText, leftOut.ToString(CultureInfo.InvariantCulture))} {text}" : text;
    }

    /// <summary>
    /// Tells the creator that sharing is on and which mods' options it shares.
    /// </summary>
    /// <param name="keys">The creator's options the world shares.</param>
    /// <returns>The sentence.</returns>
    public string CreatorOn(IReadOnlyCollection<string> keys) => keys.Count == 0 ? CreatorOnNoneText : Format(CreatorOnText, ModsText(keys));

    /// <summary>
    /// Tells the creator what someone else changed on the relay.
    /// </summary>
    /// <param name="before">The settings this game knew.</param>
    /// <param name="after">The relay's settings.</param>
    /// <returns>The notice, <see langword="null"/> when no option this game knows changed.</returns>
    public string? RelayChange(string before, string after)
    {
        if (!SharedSettings.IsShared(after))
        {
            return RelayOffText;
        }

        if (!SharedSettings.IsShared(before))
        {
            return Format(RelayOnText, ModsText(KnownKeys(SharedSettings.Values(after).Select(value => value.Key))));
        }

        return Changes(before, after) is { } changes ? Format(RelayChangedText, changes) : null;
    }

    /// <summary>
    /// Tells what changed between two of a world's settings: the first few options this game knows by
    /// name and value, the rest counted.
    /// </summary>
    /// <param name="before">The settings before.</param>
    /// <param name="after">The settings now.</param>
    /// <returns>Such as "Level Cap: On -> Off", <see langword="null"/> when nothing changed.</returns>
    public string? Changes(string before, string after)
    {
        Dictionary<string, SettingValue> was = ByKey(SharedSettings.Values(before));
        Dictionary<string, SettingValue> now = ByKey(SharedSettings.Values(after));
        List<string> keys = [.. SharedSettings.Values(after).Select(value => value.Key).Concat(SharedSettings.Values(before).Select(value => value.Key)).Distinct()
            .Where(key => !(now.TryGetValue(key, out SettingValue then) && was.TryGetValue(key, out SettingValue first) && SharedSettings.Same(first, then)))];
        if (keys.Count == 0)
        {
            return null;
        }

        List<string> named = [.. keys.Where(key => OptionOf(key) != null).Take(NamedChanges).Select(key =>
        {
            string? from = was.TryGetValue(key, out SettingValue first) ? ValueText(key, first) : null;
            string to = now.TryGetValue(key, out SettingValue then) ? ValueText(key, then) : "no longer shared";
            return $"{OptionOf(key)!.Short}: {(from != null ? $"{from} -> " : "")}{to}";
        })];
        if (named.Count == 0)
        {
            return $"{keys.Count.ToString(CultureInfo.InvariantCulture)} option{(keys.Count == 1 ? "" : "s")}";
        }

        int rest = keys.Count - named.Count;
        return rest > 0 ? $"{string.Join(", ", named)} and {rest.ToString(CultureInfo.InvariantCulture)} more" : string.Join(", ", named);
    }

    /// <summary>
    /// Writes a value as Mod Config shows it.
    /// </summary>
    /// <param name="key">The option.</param>
    /// <param name="value">The value.</param>
    /// <returns>The name Mod Config gives it, else the value.</returns>
    public string ValueText(string key, SettingValue value)
    {
        foreach ((string written, string name) in OptionOf(key)?.Names ?? [])
        {
            if (SharedSettings.Decode(written) == value)
            {
                return name;
            }
        }

        return SharedSettings.Shown(value);
    }

    /// <summary>
    /// Tells what the world screen's details say about a world's mod settings.
    /// </summary>
    /// <param name="settings">The world's settings.</param>
    /// <param name="who">"you" for the player's own world, else the creator's name.</param>
    /// <returns>Such as "Mod settings: shared by Creator (Level Cap)".</returns>
    public string Details(string settings, string who)
    {
        if (!SharedSettings.IsShared(settings))
        {
            return "Mod settings: each player's own";
        }

        List<string> keys = [.. SharedSettings.Values(settings).Select(value => value.Key)];
        if (keys.Count == 0)
        {
            return $"Mod settings: shared by {who} (none set yet)";
        }

        List<string> known = KnownKeys(keys);
        string what = known.Count == 0 ? $"{keys.Count.ToString(CultureInfo.InvariantCulture)} option{(keys.Count == 1 ? "" : "s")} of mods you lack" : ModsText(known);
        return $"Mod settings: shared by {who} ({what})";
    }

    /// <summary>
    /// Finds an option in the groups, the first group naming it.
    /// </summary>
    /// <param name="key">The option's key.</param>
    /// <returns>The option, <see langword="null"/> when no group has it.</returns>
    private SettingOption? OptionOf(string key) => groups.SelectMany(group => group.Options).FirstOrDefault(option => option.Key == key);

    /// <summary>
    /// Fills a text in, as Ruby's <c>format</c> does with <c>%s</c>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="values">What is filled in.</param>
    /// <returns>The text filled in.</returns>
    public static string Format(string text, params string[] values) => string.Format(CultureInfo.InvariantCulture, text, values);

    /// <summary>
    /// Takes values by their keys.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <returns>The values by key.</returns>
    private static Dictionary<string, SettingValue> ByKey(List<(string Key, SettingValue Value)> values) => values.ToDictionary(value => value.Key, value => value.Value);
}
