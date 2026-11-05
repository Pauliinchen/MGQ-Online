//----------------------------------------------------------------
//  ClassicStoryListsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the whole story a Classic leader sends a member as it travels packed: a story too large
/// for a message, a Float among its values, and a packed text no story makes.
/// </summary>
public sealed class ClassicStoryListsTests
{
    /// <summary>
    /// Asserts that a whole story too large for a message goes without what it turned off or set
    /// to zero and says so, and that a Float among its values reads back as the Hash of its text.
    /// </summary>
    [Fact]
    public void Full_TooLargeForAMessage_LeavesOutWhatTheStoryTurnedOff()
    {
        var lists = new RubyHash
        {
            { "s", new RubyArray { 1 } },
            { "sf", new RubyArray { 2 } },
            { "v", new RubyArray { new RubyArray { 1, 0 }, new RubyArray { 2, 5 }, new RubyArray { 3, new RubyFloat(1.5) }, new RubyArray { 4, new RubyFloat(0) } } },
            { "ss", new RubyArray { new RubyArray { 1, 2, "A" } } },
            { "ssf", new RubyArray { new RubyArray { 1, 3, "A" } } },
        };

        RubyHash whole = ClassicStoryLists.Full(lists);
        RubyHash part = ClassicStoryLists.Full(lists, 10);
        RubyValue read = MessageFields.Read(ClassicStoryLists.ListsField, MessageFields.Write(ClassicStoryLists.ListsField, part[ClassicStoryLists.ListsField]));

        Assert.Equal((false, true), (whole[ClassicStoryLists.PartField].AsBool(), part[ClassicStoryLists.PartField].AsBool()));
        Assert.Equal(
            new RubyHash
            {
                { "s", new RubyArray { 1 } },
                { "sf", new RubyArray() },
                { "v", new RubyArray { new RubyArray { 2, 5 }, new RubyArray { 3, new RubyHash { { MessageFields.FloatKey, "1.5" } } } } },
                { "ss", new RubyArray { new RubyArray { 1, 2, "A" } } },
                { "ssf", new RubyArray() },
            },
            read);
    }

    /// <summary>
    /// Asserts that a small packed text that unpacks far past any story reads as no story, so
    /// another game cannot run the player's out of memory.
    /// </summary>
    [Fact]
    public void Read_PackedTextThatUnpacksPastAnyStory_IsNone()
    {
        using var packed = new MemoryStream();
        using (var deflate = new DeflateStream(packed, CompressionLevel.Optimal, leaveOpen: true))
        {
            deflate.Write(Encoding.UTF8.GetBytes("[" + string.Concat(Enumerable.Repeat("1,", 5_000_000)) + "1]"));
        }

        string bomb = Convert.ToBase64String(packed.ToArray());

        Assert.True(bomb.Length < MessageFields.MaxPackedLength);
        Assert.True(MessageFields.Read(ClassicStoryLists.ListsField, bomb).IsNil);
    }
}
