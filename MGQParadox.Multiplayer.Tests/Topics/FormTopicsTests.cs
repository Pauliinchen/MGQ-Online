//----------------------------------------------------------------
//  FormTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Covered an empty name taken once the scripts tell that Discord told one
//      Paulinchen  2026-10-23: Registered the topics through a block, since Register answers them
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of the world screen's forms as the scripts call them.
/// </summary>
public sealed class FormTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(context => FormTopics.Register(context));

    /// <summary>
    /// Asserts that turning the type to Raid shows the Raid World's fields and ticks Turn off other mods.
    /// </summary>
    [Fact]
    public void Turn_ShowsTheFieldsOfTheTypePicked()
    {
        _topics.Call(FormTopics.Open, new RubyHash { { "form", "new_world" }, { "kind", "create" } });

        RubyHash view = _topics.Call(FormTopics.Turn, new RubyHash { { "form", "new_world" }, { "key", "type" }, { "step", 1 } })!.AsHash();

        Assert.Contains("share", Keys(view));
        Assert.DoesNotContain("choose", Keys(view));
        Assert.True(view["values"].AsHash()["other_mods_off"].AsBool());
        Assert.Equal("raid", view["derived"].AsHash()["type"].AsText());
    }

    /// <summary>
    /// Asserts that a page with a wrong field names it, and a complete one comes back tidied.
    /// </summary>
    [Fact]
    public void Send_NamesTheFirstProblemOrTidiesTheTexts()
    {
        _topics.Call(FormTopics.Open, new RubyHash { { "form", "new_world" }, { "kind", "create" } });

        Assert.Equal(new RubyArray(["name", "The world needs a name."]), _topics.Call(FormTopics.Send, new RubyHash { { "form", "new_world" } })!.AsHash()["problem"]);

        _topics.Call(FormTopics.Set, new RubyHash { { "form", "new_world" }, { "key", "name" }, { "value", "  Home " } });
        _topics.Call(FormTopics.Set, new RubyHash { { "form", "new_world" }, { "key", "seats" }, { "value", "08" } });
        RubyHash sent = _topics.Call(FormTopics.Send, new RubyHash { { "form", "new_world" } })!.AsHash();

        Assert.Equal("Home", sent["values"].AsHash()["name"].AsText());
        Assert.Equal("8", sent["values"].AsHash()["seats"].AsText());
    }

    /// <summary>
    /// Asserts that the squad rules' page shares the form's values and that an edit opens on the world.
    /// </summary>
    [Fact]
    public void Edit_OpensOnTheWorldWithItsSquadRulesOnAPageOfTheirOwn()
    {
        RubyHash world = new()
        {
            { "name", "Raid" }, { "seats", 8 }, { "mods", "" }, { "description", "" }, { "shared", false }, { "difficulty", RubyNil.Value }, { "raid", true },
            { "other_mods_off", true }, { "raid_bosses", false }, { "squad", new RubyHash { { "luka", true }, { "formation", 6 }, { "front", 2 }, { "raid_front", 3 } } },
        };
        RubyHash view = _topics.Call(FormTopics.Open, new RubyHash { { "form", "edit_world" }, { "kind", "edit" }, { "world", world }, { "own", false } })!.AsHash();

        Assert.Equal("Per player", view["fields"].AsArray().Select(field => field.AsHash()).First(field => field["key"].AsText() == "difficulty")["choices"].AsArray()[0].AsText());

        RubyHash limits = _topics.Call(FormTopics.Tick, new RubyHash { { "form", "edit_world" }, { "page", "limits" }, { "key", "luka" } })!.AsHash();

        Assert.Equal("Formation limits", limits["title"].AsText());
        Assert.False(limits["derived"].AsHash()["squad"].AsHash()["luka"].AsBool());
        Assert.Equal(6, limits["derived"].AsHash()["squad"].AsHash()["formation"].AsInt());
    }

    /// <summary>
    /// Asserts that a closed slot is refused and a check answers the tidied text.
    /// </summary>
    [Fact]
    public void Check_TidiesAndCloseForgets()
    {
        _topics.Call(FormTopics.Open, new RubyHash { { "form", "join_hidden" }, { "kind", "join" } });

        Assert.Equal(new RubyArray(["0123456789abcdef0123456789abcdef", RubyNil.Value]),
            _topics.Call(FormTopics.Check, new RubyHash { { "form", "join_hidden" }, { "key", "id" }, { "text", " 0123456789ABCDEF0123456789abcdef" } }));

        _topics.Call(FormTopics.Close, new RubyHash { { "form", "join_hidden" } });

        Assert.Equal("bad_request", _topics.Refusal(FormTopics.Check, new RubyHash { { "form", "join_hidden" }, { "key", "id" }, { "text", "" } }));
    }

    /// <summary>
    /// Asserts that the name form sends with Enter and takes an empty name only once the scripts tell
    /// that Discord told the player's.
    /// </summary>
    [Fact]
    public void Rename_TakesAnEmptyNameOnceDiscordToldOne()
    {
        RubyHash view = _topics.Call(FormTopics.Open, new RubyHash { { "form", "rename" }, { "kind", "rename" }, { "name", "" }, { "discord", false } })!.AsHash();
        Assert.True(view["sends_on_enter"].AsBool());

        Assert.Equal(new RubyArray([" ", "Type a name: Discord has not told yours yet."]),
            _topics.Call(FormTopics.Check, new RubyHash { { "form", "rename" }, { "key", "name" }, { "text", " " }, { "facts", new RubyArray() } }));
        Assert.Equal(new RubyArray(["", RubyNil.Value]),
            _topics.Call(FormTopics.Check, new RubyHash { { "form", "rename" }, { "key", "name" }, { "text", " " }, { "facts", new RubyArray(["discord"]) } }));
        Assert.False(_topics.Call(FormTopics.Send, new RubyHash { { "form", "rename" }, { "facts", new RubyArray(["discord"]) } })!.AsHash().TryGetValue("problem", out _));
    }

    /// <summary>
    /// Lists the keys of a view's fields.
    /// </summary>
    /// <param name="view">The view.</param>
    /// <returns>The keys.</returns>
    private static string[] Keys(RubyHash view) => [.. view["fields"].AsArray().Select(field => field.AsHash()["key"].AsText())];
}
