//----------------------------------------------------------------
//  WireTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics that write and read a live battle's lines (Battles/Wire), so the scripts
/// hand over and get back plain values (<see cref="WirePlain"/>) and never a line's tokens. Both
/// hosts answer them, since battles_sync.rbx hosts the battle server's battles too.
/// </summary>
public static class WireTopics
{
    /// <summary>
    /// Writes values as a line: an Array of plain values in; the line out.
    /// </summary>
    public const string Write = "wire.write";

    /// <summary>
    /// Reads a line another game sent: the line in; an Array of plain values out, nil for a line
    /// that does not read.
    /// </summary>
    public const string Read = "wire.read";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Write, (_, request) => LineOf(request));
        context.Register(Read, (_, request) => ValuesOf(request));
    }

    /// <summary>
    /// Writes the values the scripts handed over as a line.
    /// </summary>
    /// <param name="values">An Array of plain values.</param>
    /// <returns>The line.</returns>
    /// <exception cref="BridgeRequestException">A value is of no kind a line carries, or cannot be written.</exception>
    public static string LineOf(RubyValue values)
    {
        try
        {
            return WireWriter.Line(WirePlain.ListOf(values));
        }
        catch (ArgumentException e)
        {
            throw new BridgeRequestException($"The values do not go into a battle line: {e.Message}", e);
        }
    }

    /// <summary>
    /// Reads a line as the scripts take its values: each symbol, action result field and entry of
    /// the database it names, which the script finds among its own game's.
    /// </summary>
    /// <param name="line">The line, a String of any encoding.</param>
    /// <returns>An Array of plain values, nil for a line that does not read.</returns>
    public static RubyValue ValuesOf(RubyValue line)
    {
        ArgumentNullException.ThrowIfNull(line);
        IReadOnlyList<WireValue>? values = line.IsNil ? [] : WireReader.Parse(line.AsBytes().Span, WireGame.Any);
        return values is null ? RubyNil.Value : WirePlain.ToPlain(values);
    }
}
