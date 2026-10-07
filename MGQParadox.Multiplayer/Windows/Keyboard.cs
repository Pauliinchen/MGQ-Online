//----------------------------------------------------------------
//  Keyboard.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Kept a take the game script had no room for, which the next take hands out first
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// What the player types into the game's window while a text screen of the game script wants it,
/// with the keyboard's layout, Shift and AltGr, since RGSS itself only knows buttons.
/// </summary>
/// <remarks>
/// The characters come from the window's WM_CHAR messages, which Windows makes only when the
/// message loop translates key presses. Until one arrives, the characters are worked out from
/// the key presses themselves, which works whether RGSS translates or not, but combines no
/// accents typed as dead keys.
/// </remarks>
internal static partial class Keyboard
{
    /// <summary>
    /// The character Ctrl+V types, which pastes the clipboard.
    /// </summary>
    private const char Paste = '\u0016';

    /// <summary>
    /// Asks ToUnicodeEx to leave the keyboard's state alone, so RGSS's own translating stays as it is.
    /// </summary>
    private const uint KeepKeyboardState = 0x4;

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private static readonly object Gate = new();

    /// <summary>
    /// The characters from WM_CHAR since the last take.
    /// </summary>
    private static readonly StringBuilder FromMessages = new();

    /// <summary>
    /// The characters worked out from key presses since the last take.
    /// </summary>
    private static readonly StringBuilder FromKeys = new();

    /// <summary>
    /// Whether a text screen wants what is typed.
    /// </summary>
    private static bool active;

    /// <summary>
    /// Whether a WM_CHAR ever arrived, so RGSS translates key presses and those characters count.
    /// </summary>
    private static bool translated;

    /// <summary>
    /// How many keys went down since the last take, which tells a keyboard from a gamepad.
    /// </summary>
    private static int keys;

    /// <summary>
    /// The characters of a take given back, which the next take hands out first.
    /// </summary>
    private static string givenBack = string.Empty;

    /// <summary>
    /// The keys of a take given back, which the next take counts too.
    /// </summary>
    private static int givenBackKeys;

    /// <summary>
    /// Whether a text screen wants what is typed.
    /// </summary>
    public static bool Active => Volatile.Read(ref active);

    /// <summary>
    /// Starts or stops taking what is typed, forgetting what came before.
    /// </summary>
    /// <param name="on">Whether to take it.</param>
    public static void SetActive(bool on)
    {
        lock (Gate)
        {
            active = on;
            FromMessages.Clear();
            FromKeys.Clear();
            keys = 0;
            givenBack = string.Empty;
            givenBackKeys = 0;
        }
    }

    /// <summary>
    /// Takes a WM_CHAR's character.
    /// </summary>
    /// <param name="character">The character.</param>
    public static void TakeCharacter(char character)
    {
        lock (Gate)
        {
            if (!translated)
            {
                translated = true;
                Log.Write("keyboard: the game window gets typed characters");
            }

            FromMessages.Append(character);
        }
    }

    /// <summary>
    /// Takes a key press, working out its characters as long as no WM_CHAR arrived.
    /// </summary>
    /// <param name="virtualKey">The key's virtual key code.</param>
    /// <param name="scanCode">The key's scan code.</param>
    public static void TakeKey(uint virtualKey, uint scanCode)
    {
        lock (Gate)
        {
            keys++;

            if (!translated)
            {
                FromKeys.Append(Characters(virtualKey, scanCode));
            }
        }
    }

    /// <summary>
    /// Hands out what was typed since the last take, the clipboard's text in place of Ctrl+V.
    /// </summary>
    /// <returns>The characters, Enter, Backspace and Escape among them as \r, \b and \u001b; and how many keys went down.</returns>
    public static (string Text, int Keys) Take()
    {
        string typed;
        string returned;
        int pressed;

        lock (Gate)
        {
            typed = (translated ? FromMessages : FromKeys).ToString();
            returned = givenBack;
            pressed = keys + givenBackKeys;
            FromMessages.Clear();
            FromKeys.Clear();
            keys = 0;
            givenBack = string.Empty;
            givenBackKeys = 0;
        }

        if (typed.Contains(Paste))
        {
            var pasted = new string((Clipboard.GetText() ?? string.Empty).Where(character => !char.IsControl(character)).ToArray());
            typed = typed.Replace(Paste.ToString(), pasted);
        }

        return (returned + typed, pressed);
    }

    /// <summary>
    /// Gives a take back that could not be handed out, so the next take hands it out first.
    /// </summary>
    /// <param name="text">The take's characters, as <see cref="Take"/> handed them out.</param>
    /// <param name="pressed">The take's keys.</param>
    public static void GiveBack(string text, int pressed)
    {
        lock (Gate)
        {
            givenBack = text + givenBack;
            givenBackKeys += pressed;
        }
    }

    /// <summary>
    /// Works out the characters a key press types with the keyboard's layout and the keys held.
    /// </summary>
    /// <param name="virtualKey">The key's virtual key code.</param>
    /// <param name="scanCode">The key's scan code.</param>
    /// <returns>The characters, none for a key that types nothing.</returns>
    private static unsafe string Characters(uint virtualKey, uint scanCode)
    {
        var state = stackalloc byte[256];
        var buffer = stackalloc char[8];

        if (!GetKeyboardState(state))
        {
            return string.Empty;
        }

        var count = ToUnicodeEx(virtualKey, scanCode, state, buffer, 8, KeepKeyboardState, GetKeyboardLayout(0));
        return count > 0 ? new string(buffer, 0, count) : string.Empty;
    }

    /// <summary>
    /// Reads which keys are down, as the thread's messages left them.
    /// </summary>
    /// <param name="state">256 bytes, one per virtual key.</param>
    /// <returns><see langword="true"/> when it was read.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static unsafe partial bool GetKeyboardState(byte* state);

    /// <summary>
    /// Works out the characters of a key with a keyboard layout.
    /// </summary>
    /// <param name="virtualKey">The key's virtual key code.</param>
    /// <param name="scanCode">The key's scan code.</param>
    /// <param name="state">Which keys are down.</param>
    /// <param name="buffer">Receives the characters.</param>
    /// <param name="size">The buffer's size in characters.</param>
    /// <param name="flags">How to work them out.</param>
    /// <param name="layout">The keyboard layout.</param>
    /// <returns>The number of characters, negative for a dead key, 0 for none.</returns>
    [LibraryImport("user32.dll")]
    private static unsafe partial int ToUnicodeEx(uint virtualKey, uint scanCode, byte* state, char* buffer, int size, uint flags, nint layout);

    /// <summary>
    /// Finds a thread's keyboard layout.
    /// </summary>
    /// <param name="thread">The thread, 0 for this one.</param>
    /// <returns>The layout.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint GetKeyboardLayout(uint thread);
}
