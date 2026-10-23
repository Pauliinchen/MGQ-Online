//----------------------------------------------------------------
//  LastErrorTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using MGQParadox.Multiplayer.Reports;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// Covers telling where the newest error of <c>errors.txt</c> was raised.
/// </summary>
public sealed class LastErrorTests
{
    /// <summary>
    /// An error raised in a script of MGQ Online, as the game writes it, with Ruby's escapes.
    /// </summary>
    private const string OwnError =
        "*Error - v3.06.00 - 2026-10-18 12:30:01 (Sunday)\r\nException : NoMethodError\r\nundefined method `hp' for nil:NilClass\r\ntrace:\r\n" +
        "[\"Patch\\\\Multiplayer\\\\Scripts\\\\battles_pvp.rbx:328:in `block in install_targetless'\", \"Patch\\\\Multiplayer\\\\Scripts\\\\core_hooks.rbx:158:in `call'\", \"( Scene_Battle )：48:in `update'\"]\r\n";

    /// <summary>
    /// Asserts that an error raised in a script of MGQ Online names the script.
    /// </summary>
    [Fact]
    public void PlaceOf_OwnScriptOnTop_NamesTheScript()
    {
        Assert.Equal("raised in MGQ Online (battles_pvp.rbx)", LastError.PlaceOf(OwnError));
    }

    /// <summary>
    /// Asserts that the newest error counts, and that one raised in code the Patch folder's loader
    /// ran is not put on MGQ Online, even when MGQ Online's hooks are further down its trace (issue 33).
    /// </summary>
    [Fact]
    public void PlaceOf_NewestErrorInAnotherMod_IsNotPutOnTheMod()
    {
        var errors = OwnError +
            "*Error - v3.06.00 - 2026-10-18 12:41:27 (Sunday)\r\nException : NameError\r\nundefined local variable or method `make_true_random_action'\r\ntrace:\r\n" +
            "[\"(eval):807:in `block in auto_battle_actions'\", \"Patch\\\\Multiplayer\\\\Scripts\\\\core_hooks.rbx:158:in `call'\", \"( Scene_Battle )：45:in `update'\"]\r\n";

        Assert.Equal("raised in a Patch folder script, such as another mod", LastError.PlaceOf(errors));
    }

    /// <summary>
    /// Asserts that an error raised in the game's scripts names their section.
    /// </summary>
    [Fact]
    public void PlaceOf_GameSectionOnTop_NamesTheSection()
    {
        var errors = "*Error - v3.06.00 - 2026-10-18 12:30:01 (Sunday)\nException : NoMethodError\nundefined method `[]' for nil:NilClass\ntrace:\n" +
            "[\"( エンチャント/n )：357:in `set_enchants_fast'\", \"( ベース/GameObject )：7743:in `block in gain_item'\"]\n";

        Assert.Equal("raised in the game (エンチャント/n)", LastError.PlaceOf(errors));
    }

    /// <summary>
    /// Asserts that an error without a trace, or no error at all, tells nothing.
    /// </summary>
    [Fact]
    public void PlaceOf_WithoutATrace_IsNull()
    {
        Assert.Null(LastError.PlaceOf("*Error - v3.06.00 - 2026-10-18 12:30:01 (Sunday)\nException : SystemExit\nexit\n"));
        Assert.Null(LastError.PlaceOf(string.Empty));
    }
}
