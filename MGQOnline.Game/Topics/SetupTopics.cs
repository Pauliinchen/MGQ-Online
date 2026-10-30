//----------------------------------------------------------------
//  SetupTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Served;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the setup a served battle's starter hands the battle server, see
/// <see cref="ServedSetup"/> and <see cref="ScriptsFingerprint"/>, which both hosts answer through
/// <see cref="SharedTopics"/>: the starter's game writes it, the server reads and checks it.
/// </summary>
public static class SetupTopics
{
    /// <summary>
    /// Writes a setup: the starter's facts by name in (see <see cref="ServedSetup.Write"/>); the battle line out.
    /// </summary>
    public const string Write = "served.setup.write";

    /// <summary>
    /// Reads a setup: the battle line in; its fields by name out (see <see cref="ServedSetup.Read"/>),
    /// nil for a setup of another format.
    /// </summary>
    public const string Read = "served.setup.read";

    /// <summary>
    /// Checks a setup as the battle server does: <c>text</c>, the server's <c>scripts</c> and
    /// <c>data</c> fingerprints and <c>troop_enemies</c> (whether the setup's troop has enemies in
    /// the server's database) in; [code, why] out, nil for a setup the server hosts.
    /// </summary>
    public const string Check = "served.setup.check";

    /// <summary>
    /// Finds the scripts' fingerprint: [name, text] per script in the order the game loads them in;
    /// eight hexadecimal digits out.
    /// </summary>
    public const string Fingerprint = "served.fingerprint";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Write, (_, request) => ServedSetup.Write(request.AsHash()));
        context.Register(Read, (_, request) => ServedSetup.Read(request.AsText()));
        context.Register(Check, (_, request) => CheckOf(request.AsHash()));
        context.Register(Fingerprint, (_, request) =>
            ScriptsFingerprint.Of(request.AsArray().Select(script => script.AsArray()).Select(script => (script[0].AsBytes().ToArray(), script[1].AsBytes().ToArray()))));
    }

    /// <summary>
    /// Answers <see cref="Check"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The refusal's code and why, nil for none.</returns>
    private static RubyValue? CheckOf(RubyHash request) =>
        ServedSetup.Refusal(request["text"].AsText(), request["scripts"].AsText(), request["data"].AsText(), request["troop_enemies"].AsBool()) is { } refusal
            ? new RubyArray([refusal.Code, refusal.Why])
            : null;
}
