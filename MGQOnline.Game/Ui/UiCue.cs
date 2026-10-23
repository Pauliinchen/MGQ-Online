//----------------------------------------------------------------
//  UiCue.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Ui;

/// <summary>
/// The sounds a model names in its event's "cues", which the scripts play with the game's system
/// sounds (MGQ_MpUi::Tick::CUES).
/// </summary>
public static class UiCue
{
    /// <summary>Sound.play_ok.</summary>
    public const string Ok = "ok";

    /// <summary>Sound.play_cancel.</summary>
    public const string Cancel = "cancel";

    /// <summary>Sound.play_cursor.</summary>
    public const string Cursor = "cursor";

    /// <summary>Sound.play_buzzer.</summary>
    public const string Buzzer = "buzzer";

    /// <summary>
    /// The key of the cues in a model's event.
    /// </summary>
    public const string Key = "cues";
}
