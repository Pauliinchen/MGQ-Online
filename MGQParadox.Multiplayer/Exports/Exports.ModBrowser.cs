//----------------------------------------------------------------
//  Exports.ModBrowser.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Added mp_mod_browser_details
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of the Mods screen of the title: the mods of the website and the relay with how
/// each stands in the Patch folder, installing, updating and removing them, a mod's description,
/// and opening a mod's page.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Starts fetching the mods of the website and the relay and scanning the Patch folder. Returns
    /// at once; how it went follows in <c>mp_mod_browser_list</c>.
    /// </summary>
    /// <returns>1 when started, 0 while a fetch runs or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mod_browser_refresh", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModBrowserRefresh()
    {
        try
        {
            return ModBrowser.Current.Refresh() ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mod_browser_refresh failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the mods and the last action, see <see cref="ModBrowser.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives the list, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The list's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mod_browser_list", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModBrowserList(byte* buffer, int size)
    {
        try
        {
            return Copy(ModBrowser.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mod_browser_list failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Installs, updates and removes mods of the list as one action. Returns at once; how it went
    /// follows in <c>mp_mod_browser_list</c>.
    /// </summary>
    /// <param name="lines">One line per mod, UTF-8 and null-terminated: <c>install</c> or <c>remove</c>, a tab, and the mod's id.</param>
    /// <returns>1 when started, 0 while an action runs, before the first list, for a mod the list lacks or cannot remove, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mod_browser_apply", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModBrowserApply(byte* lines)
    {
        try
        {
            var actions = Text(lines).Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(line => line.Split('\t', 2))
                .Select(parts => (Verb: parts[0], Id: parts.Length > 1 ? parts[1] : string.Empty))
                .ToList();

            return actions.Count > 0 && ModBrowser.Current.Apply(actions) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mod_browser_apply failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts fetching the description of a mod of the website, unless it is known or being fetched.
    /// Returns at once; its lines follow in <c>mp_mod_browser_list</c>.
    /// </summary>
    /// <param name="id">The mod's id, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, known or being fetched, 0 for a mod the list lacks, one not of the website, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mod_browser_details", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModBrowserDetails(byte* id)
    {
        try
        {
            return ModBrowser.Current.Details(Text(id)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mod_browser_details failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Opens a mod's page in the player's browser, if it is on the website or on GitHub.
    /// </summary>
    /// <param name="id">The mod's id, UTF-8 and null-terminated.</param>
    /// <returns>1 when opened, 0 when the mod has no such page or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mod_browser_open_page", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModBrowserOpenPage(byte* id)
    {
        try
        {
            return ModBrowser.Current.OpenPage(Text(id)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mod_browser_open_page failed: {ex}");
            return 0;
        }
    }
}
