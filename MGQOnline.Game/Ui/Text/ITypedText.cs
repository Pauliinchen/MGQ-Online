//----------------------------------------------------------------
//  ITypedText.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Ui.Text;

/// <summary>
/// What the player typed into the game's window, which the DLL's keyboard hands out.
/// </summary>
public interface ITypedText
{
    /// <summary>
    /// Hands out what was typed since the last take.
    /// </summary>
    /// <returns>The characters, Enter, Backspace and Escape among them as \r, \b and \u001b, the
    /// clipboard's text in place of Ctrl+V; and how many keys went down.</returns>
    (string Text, int Keys) Take();
}
