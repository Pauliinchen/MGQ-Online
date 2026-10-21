//----------------------------------------------------------------
//  AfterUpdateArgumentsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Linq;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests the arguments the replaced program hands the new one.
/// </summary>
public sealed class AfterUpdateArgumentsTests
{
    /// <summary>
    /// The arguments are the switch, the pid, the start ticks and the old version.
    /// </summary>
    [Fact]
    public void WritesTheContractLayout()
    {
        var arguments = new AfterUpdateArguments(new ProcessStamp(4321, 638_960_000_000_000_000), ReleaseVersion.Parse("1.3.0"));

        Assert.Equal(["--after-update", "4321", "638960000000000000", "1.3.0"], arguments.ToArguments());
    }

    /// <summary>
    /// Written arguments are found again among other arguments.
    /// </summary>
    [Fact]
    public void FindsWrittenArguments()
    {
        var written = new AfterUpdateArguments(ProcessStamp.Current(), ReleaseVersion.Parse("1.3.0-beta.1"));
        string[] commandLine = ["--server", "x", .. written.ToArguments(), "--more"];

        Assert.Equal(written, AfterUpdateArguments.Find(commandLine));
    }

    /// <summary>
    /// A command line without the switch, or with missing or wrong values, finds nothing.
    /// </summary>
    /// <param name="commandLine">The arguments, separated by spaces.</param>
    [Theory]
    [InlineData("")]
    [InlineData("--server x")]
    [InlineData("--after-update")]
    [InlineData("--after-update 4321 638960000000000000")]
    [InlineData("--after-update x 638960000000000000 1.3.0")]
    [InlineData("--after-update -1 638960000000000000 1.3.0")]
    [InlineData("--after-update 4321 ticks 1.3.0")]
    [InlineData("--after-update 4321 638960000000000000 latest")]
    public void FindsNothingElse(string commandLine)
    {
        var args = commandLine.Split(' ').Where(part => part.Length > 0).ToArray();

        Assert.Null(AfterUpdateArguments.Find(args));
    }
}
