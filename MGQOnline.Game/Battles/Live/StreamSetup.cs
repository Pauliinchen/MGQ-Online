//----------------------------------------------------------------
//  StreamSetup.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// What the guest checks the host's stream against in a battle, from its scripts and game: the host's
/// names and its own, whether it has the translation's name box, the methods the hooks record, the
/// calls it makes itself and how many animations its database holds.
/// </summary>
/// <param name="HostNames">The host's names line: its party's names, then its troop's;
/// <see langword="null"/> before the host's battle is ready.</param>
/// <param name="OwnParty">The names of the guest's battlers the host's party stands for, by place.</param>
/// <param name="OwnTroop">The names of the guest's battlers the host's troop stands for, by place.</param>
/// <param name="NameBox">Whether the guest's game shows the translation's name box.</param>
/// <param name="LogMethods">The battle log's primitives the hooks record.</param>
/// <param name="PictureMethods">What the hooks record of pictures.</param>
/// <param name="ScreenMethods">What the hooks record of the screen.</param>
/// <param name="AudioMethods">What the hooks record of Audio.</param>
/// <param name="SceneCalls">The battle's methods the guest calls itself.</param>
/// <param name="LogCalls">The battle log's methods the guest calls itself.</param>
/// <param name="Animations">The size of the guest's animations table, its entry 0 counted.</param>
public sealed record StreamSetup(
    byte[]? HostNames,
    IReadOnlyList<string> OwnParty,
    IReadOnlyList<string> OwnTroop,
    bool NameBox,
    IReadOnlySet<string> LogMethods,
    IReadOnlySet<string> PictureMethods,
    IReadOnlySet<string> ScreenMethods,
    IReadOnlySet<string> AudioMethods,
    IReadOnlySet<string> SceneCalls,
    IReadOnlySet<string> LogCalls,
    int Animations)
{
    /// <summary>
    /// Gets the setup before the guest's first, which lets nothing of the host's but plain events in.
    /// </summary>
    public static StreamSetup Empty { get; } = new(
        null, [], [], true, new HashSet<string>(), new HashSet<string>(), new HashSet<string>(),
        new HashSet<string>(), new HashSet<string>(), new HashSet<string>(), 0);
}
