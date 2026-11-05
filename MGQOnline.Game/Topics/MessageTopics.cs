//----------------------------------------------------------------
//  MessageTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Wrote and handed back each field by its kind in MessageFields
//                            - Read the fields a request passed on carries as pairs
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics that write and read the messages games send each other, in the world room and
/// on a battle channel, so the scripts hand over fields and a body and never a message's text. Both
/// hosts answer them; the battle server's scripts send through them.
/// </summary>
public static class MessageTopics
{
    /// <summary>
    /// Writes a message: <c>fields</c> (a Hash, see <see cref="FieldsOf"/>) and <c>body</c> in; the
    /// message's text out.
    /// </summary>
    public const string Write = "message.write";

    /// <summary>
    /// Reads a message: its text in; <c>fields</c> (by name, see <see cref="HashOf"/>) and
    /// <c>body</c> out.
    /// </summary>
    public const string Read = "message.read";

    /// <summary>
    /// Reads fields another game wrote that came as [name, text] pairs, as a request a served
    /// battle's starter passes on carries them: the pairs in; the fields by name out, see
    /// <see cref="HashOf"/>.
    /// </summary>
    public const string ReadPairs = "message.read_pairs";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Write, (_, request) =>
        {
            RubyHash message = request.AsHash();
            return FieldsOf(message["fields"].AsHash()).Encode(BodyOf(message["body"]));
        });
        context.Register(Read, (_, request) =>
        {
            WorldFields fields = WorldFields.Parse(BodyOf(request), out string body);
            return new RubyHash { { "fields", HashOf(fields) }, { "body", body } };
        });
        context.Register(ReadPairs, (_, request) =>
        {
            var fields = new WorldFields();
            foreach (RubyValue pair in request.AsArray())
            {
                fields.Set(pair.AsArray()[0].AsText(), pair.AsArray()[1].AsText());
            }

            return HashOf(fields);
        });
    }

    /// <summary>
    /// Takes a message's fields the scripts handed over, each written as
    /// <see cref="MessageFields.Write"/> writes its kind: a field the table does not name holds a
    /// text, a number, true, false, nil or a list of these.
    /// </summary>
    /// <param name="hash">The fields by name.</param>
    /// <returns>The fields.</returns>
    /// <exception cref="BridgeRequestException">A value is not of its field's kind.</exception>
    public static WorldFields FieldsOf(RubyHash hash)
    {
        ArgumentNullException.ThrowIfNull(hash);
        var fields = new WorldFields();
        foreach (KeyValuePair<RubyValue, RubyValue> pair in hash)
        {
            string name = MessageFields.TextOf(pair.Key);
            fields.Set(name, MessageFields.Write(name, pair.Value));
        }

        return fields;
    }

    /// <summary>
    /// Hands fields another game wrote to the scripts, each as <see cref="MessageFields.Read"/>
    /// reads its kind: a field the table does not name as its text.
    /// </summary>
    /// <param name="fields">The fields.</param>
    /// <returns>The Hash.</returns>
    public static RubyHash HashOf(WorldFields fields)
    {
        ArgumentNullException.ThrowIfNull(fields);
        var hash = new RubyHash();
        foreach (KeyValuePair<string, string> pair in fields)
        {
            hash.Add(pair.Key, MessageFields.Read(pair.Key, pair.Value));
        }

        return hash;
    }

    /// <summary>
    /// Reads a body or a message's text, a String of any encoding taken as UTF-8, since the game's
    /// Ruby leaves some texts as bytes.
    /// </summary>
    /// <param name="value">The value, nil for an empty one.</param>
    /// <returns>The text.</returns>
    public static string BodyOf(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return value.IsNil ? string.Empty : System.Text.Encoding.UTF8.GetString(value.AsBytes().Span);
    }
}
