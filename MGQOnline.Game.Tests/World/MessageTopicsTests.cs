//----------------------------------------------------------------
//  MessageTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Expected the fields the table names back as values
//                            - Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Tests of the topics that write and read the messages games send each other, which the battle
/// server's scripts send through.
/// </summary>
public sealed class MessageTopicsTests
{
    /// <summary>
    /// Asserts that the fields and the body the scripts hand over are written as one message and
    /// read back as the receiving game's scripts get them: a field of MessageFields' table as its
    /// value, another as its text, a line break in a value as a space.
    /// </summary>
    [Fact]
    public void WriteAndRead_GiveTheScriptsTheirFieldsBack()
    {
        var topics = new TopicContext();
        MessageTopics.Register(topics.Context);
        var fields = new RubyHash
        {
            { "battle", "front_out" },
            { "seats", new RubyArray { 4, 7 } },
            { "turn", 3 },
            { "escape", true },
            { "none", RubyNil.Value },
            { "note", "two\nlines" },
        };

        RubyHash written = topics.Call(MessageTopics.Write, new RubyHash { { "fields", fields }, { "body", "アリス\n\nルカ" } })!;
        RubyHash read = topics.Call(MessageTopics.Read, written["value"])!["value"].AsHash();

        Assert.Equal(
            new RubyHash { { "battle", "front_out" }, { "seats", new RubyArray { 4, 7 } }, { "turn", "3" }, { "escape", true }, { "none", string.Empty }, { "note", "two lines" } },
            read["fields"]);
        Assert.Equal("アリス\n\nルカ", read["body"].AsText());
    }

    /// <summary>
    /// Asserts that a field holding a Hash is refused, so no script's value is written as Ruby's
    /// text of it.
    /// </summary>
    [Fact]
    public void Write_HashInAField_IsRefused()
    {
        var topics = new TopicContext();
        MessageTopics.Register(topics.Context);

        RubyHash refused = topics.Call(MessageTopics.Write, new RubyHash { { "fields", new RubyHash { { "bad", new RubyHash() } } }, { "body", string.Empty } })!;

        Assert.False(refused["ok"].AsBool());
    }
}
