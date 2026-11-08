//----------------------------------------------------------------
//  ScreenTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Handed out the details' captions by their column
//                            - Handed out the list box's lines of a world's World facts and of its Game data apart
//                            - Told the scripts which panel of the details shows its rows as lines
//                            - Handed every caption the details can show with a world's details
//                            - Marked the rows the search and the filters the scripts pass show, and told the list's text while they hide every world
//                            - Told the scripts the list changed only once what it shows changed
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Worlds;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the world screen's model: the list it shows, a world's details, its choices
/// and the list box's lines, the screen's texts and the list's refresh while it is open.
/// </summary>
internal static class ScreenTopics
{
    /// <summary>
    /// Opens the screen, which fetches the list at once and every ten seconds after: nothing in or out.
    /// </summary>
    public const string Open = "screen.open";

    /// <summary>
    /// Closes the screen, which stops the refresh: nothing in or out.
    /// </summary>
    public const string Close = "screen.close";

    /// <summary>
    /// Hands out the screen's texts: nothing in; <c>hint</c>, <c>enter_hint</c> and <c>busy</c> (what the
    /// screen says while an action runs, by its kind) out.
    /// </summary>
    public const string Texts = "screen.texts";

    /// <summary>
    /// Hands out the list as it stands: the search and the filters in (<c>search</c>, <c>type</c> "all",
    /// "raid" or "classic", and <c>online</c>; nil for none); <c>state</c>, <c>error</c>, <c>admin</c>,
    /// <c>info</c> (the list's line at the top, nil for none), <c>empty</c> (what the list says while
    /// the filters hide every world, nil otherwise) and <c>rows</c> (see <see cref="RowValue"/>) out.
    /// </summary>
    public const string List = "screen.list";

    /// <summary>
    /// Finds one world in the list as it stands: its id in; <c>state</c> and <c>listed</c> (see
    /// <see cref="ListedValue"/>, nil when the list lacks it) out.
    /// </summary>
    public const string World = "screen.world";

    /// <summary>
    /// Hands out a world's details: its row's key in; <c>title</c>, <c>title_color</c>, <c>played</c>,
    /// <c>panels</c> (see <see cref="PanelValue"/>), <c>captions</c> (every caption the details can show, by column, see
    /// <see cref="WorldScreenModel.DetailCaptions"/>) and <c>description</c> (nil for a world the list lacks) out; nil for a key the list lacks.
    /// </summary>
    public const string Details = "screen.details";

    /// <summary>
    /// Hands out what can be done with a world: its row's key in; [label, symbol, enabled] each out;
    /// nil for a key the list lacks.
    /// </summary>
    public const string Actions = "screen.actions";

    /// <summary>
    /// Hands out the list box's lines of a world: <c>key</c> and <c>kind</c> ("players", "mods", "world" or "data") in;
    /// ["head", text] or ["item", text, color, note] each out; nil for a key the list lacks.
    /// </summary>
    public const string Box = "screen.box";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="screen">The screen's model.</param>
    /// <param name="changes">The changes the scripts are told of.</param>
    /// <param name="listRevision">Reads the directory list's revision.</param>
    public static void Register(BridgeContext context, WorldScreen screen, WorldChanges changes, System.Func<long> listRevision)
    {
        ScreenRules rules = WorldScreen.Rules();
        changes.Watch(() => screen.Revision, WorldChanges.List | WorldChanges.Details);
        context.EveryFrame(drained => screen.Tick(drained.Frame, listRevision()));
        context.Register(Open, (drained, _) =>
        {
            screen.Open(drained.Frame);
            return null;
        });
        context.Register(Close, (_, _) =>
        {
            screen.Close();
            return null;
        });
        context.Register(Texts, (_, _) => TextsValue());
        context.Register(List, (drained, request) => ListValue(screen.ListFor(FilterOf(request), drained.Frame)));
        context.Register(World, (_, request) => OneWorld(screen, request.AsText()));
        context.Register(Details, (_, request) => screen.Find(request.AsText()) is { } item ? DetailsValue(item, screen.FactsOf(item), rules) : null);
        context.Register(Actions, (_, request) => screen.Find(request.AsText()) is { } item
            ? new RubyArray(WorldScreenModel.Actions(item.View, screen.FactsOf(item)).Select(action => (RubyValue)new RubyArray([action.Label, action.Symbol, action.Enabled])))
            : null);
        context.Register(Box, (_, request) => BoxValue(screen, rules, request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Texts"/>.
    /// </summary>
    /// <returns>The texts.</returns>
    private static RubyHash TextsValue()
    {
        RubyHash busy = new();
        foreach ((string kind, string text) in WorldScreenModel.BusyTexts)
        {
            busy[kind] = text;
        }

        return new RubyHash { { "hint", WorldScreenModel.Hint }, { "enter_hint", WorldScreenModel.EnterHint }, { "busy", busy } };
    }

    /// <summary>
    /// Reads the search and the filters the scripts pass with <see cref="List"/>.
    /// </summary>
    /// <param name="request">The request, nil for none.</param>
    /// <returns>The search and the filters.</returns>
    private static ScreenFilter FilterOf(RubyValue request)
    {
        if (request is not RubyHash asked)
        {
            return ScreenFilter.None;
        }

        string search = asked["search"] is RubyString text ? text.Text : string.Empty;
        string type = asked["type"] is RubyString kind ? kind.Text : WorldScreenModel.AllTypes;
        return new ScreenFilter(search, type, asked["online"] is RubyBool { Flag: true });
    }

    /// <summary>
    /// Answers <see cref="List"/>.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The list for the scripts.</returns>
    internal static RubyHash ListValue(ScreenList list) => new()
    {
        { "state", list.State },
        { "error", list.Error },
        { "admin", list.Admin },
        { "info", WorldScreenModel.ListText(list.State, list.Error) },
        { "empty", WorldScreenModel.EmptyText(list.Items.Count, list.Items.Count(list.Shows), list.Filter) },
        { "rows", new RubyArray(list.Items.Select(item => RowValue(item, list.Shows(item)))) },
    };

    /// <summary>
    /// Describes a row of the list for the scripts.
    /// </summary>
    /// <param name="item">The world.</param>
    /// <param name="shown">Whether the search and the filters show it.</param>
    /// <returns><c>key</c>, <c>id</c> (nil for a folder whose world.ini names none), <c>name</c>, <c>text</c>,
    /// <c>count</c>, <c>color</c> and <c>dim</c> (see <see cref="ScreenRow"/>), <c>favourite</c>, <c>gone</c>,
    /// <c>shown</c>, <c>listed</c> (see <see cref="ListedValue"/>) and <c>local</c> (see <see cref="LocalWorldTopics.WorldOf"/>).</returns>
    private static RubyValue RowValue(ScreenItem item, bool shown)
    {
        ScreenRow row = WorldScreenModel.RowOf(item.View);
        return new RubyHash
        {
            { "key", item.Key },
            { "id", item.Entry.Id },
            { "name", item.Entry.Name },
            { "text", row.Text },
            { "count", row.Count },
            { "color", row.Color },
            { "dim", row.Dim },
            { "favourite", item.Entry.Favourite },
            { "gone", item.Entry.Gone },
            { "shown", shown },
            { "listed", item.Listed == null ? RubyNil.Value : ListedValue(item.Listed) },
            { "local", item.Folder == null ? RubyNil.Value : LocalWorldTopics.WorldOf(item.Folder) },
        };
    }

    /// <summary>
    /// Describes a world of the directory for the scripts, as they read the list's line of it before.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>Every field of the scripts' ListedWorld by its name, <c>members</c> as [id, online, name] each, <c>squad</c> as
    /// <c>squad.read</c> answers it.</returns>
    internal static RubyHash ListedValue(ListedWorld world)
    {
        ScreenListed view = WorldScreen.ListedOf(world);
        return new RubyHash
        {
            { "id", view.Id },
            { "seats", view.Seats },
            { "online", view.Online },
            { "creator_id", view.CreatorId },
            { "active", world.Active },
            { "creator_name", view.CreatorName },
            { "name", view.Name },
            { "start", view.Start },
            { "members", new RubyArray(view.Members.Select(member => (RubyValue)new RubyArray([member.Id, member.Online, member.Name]))) },
            { "hidden", view.Hidden },
            { "choose", view.Choose },
            { "open", view.Open },
            { "featured", view.Featured },
            { "strict", view.Strict },
            { "data", WorldScreen.OnOneField(world.About.Data) },
            { "mods", view.Mods },
            { "description", WorldScreen.OnOneField(world.About.Description) },
            { "mod_hashes", WorldScreen.OnOneField(world.About.ModHashes) },
            { "settings", WorldScreen.OnOneField(world.About.Settings) },
            { "type", view.Type },
            { "share", view.Share },
            { "difficulty", view.Difficulty is { } difficulty ? difficulty : RubyNil.Value },
            { "other_mods_off", view.OtherModsOff },
            { "squad", view.Squad is { } squad ? new RubyHash { { "luka", squad.Luka }, { "formation", squad.Formation }, { "front", squad.Front }, { "raid_front", squad.RaidFront } } : RubyNil.Value },
            { "raid_bosses", view.RaidBosses },
            { "mods_unread", view.ModsUnread },
        };
    }

    /// <summary>
    /// Answers <see cref="World"/>.
    /// </summary>
    /// <param name="screen">The screen's model.</param>
    /// <param name="id">The world's id.</param>
    /// <returns>The list's state and the world.</returns>
    private static RubyHash OneWorld(WorldScreen screen, string id)
    {
        (string state, ListedWorld? world) = screen.ListedNow(id);
        return new RubyHash { { "state", state }, { "listed", world == null ? RubyNil.Value : ListedValue(world) } };
    }

    /// <summary>
    /// Answers <see cref="Details"/>.
    /// </summary>
    /// <param name="item">The world.</param>
    /// <param name="facts">What its details read beyond it.</param>
    /// <param name="rules">The rules the details name.</param>
    /// <returns>The details.</returns>
    private static RubyHash DetailsValue(ScreenItem item, ScreenFacts facts, ScreenRules rules) => new()
    {
        { "title", item.View.Name },
        { "title_color", WorldScreenModel.TitleColor(item.View) },
        { "played", WorldScreenModel.PlayedText(item.View.Local) },
        { "panels", new RubyArray(WorldScreenModel.Panels(item.View, facts, rules).Select(PanelValue)) },
        { "captions", new RubyArray(WorldScreenModel.DetailCaptions.Select(column => (RubyValue)new RubyArray(column.Select(caption => (RubyValue)caption)))) },
        { "description", item.Listed == null ? RubyNil.Value : WorldScreen.OnOneField(item.Listed.About.Description) },
    };

    /// <summary>
    /// Describes a panel of the details for the scripts.
    /// </summary>
    /// <param name="panel">The panel.</param>
    /// <returns><c>title</c>, <c>note</c>, <c>target</c>, <c>lines</c> and <c>rows</c>, each row its cells (nil for a missing one) as
    /// <c>label</c>, <c>text</c>, <c>color</c>, <c>target</c>, <c>chips</c> and <c>chip_colors</c> ([text, color] each).</returns>
    private static RubyValue PanelValue(ScreenPanel panel) => new RubyHash
    {
        { "title", panel.Title },
        { "note", panel.Note },
        { "target", panel.Target },
        { "lines", panel.Lines },
        { "rows", new RubyArray(panel.Rows.Select(row => (RubyValue)new RubyArray(row.Select(CellValue)))) },
    };

    /// <summary>
    /// Describes a cell of the details for the scripts.
    /// </summary>
    /// <param name="cell">The cell, <see langword="null"/> for none.</param>
    /// <returns>The cell, nil for none.</returns>
    private static RubyValue CellValue(ScreenCell? cell) => cell == null ? RubyNil.Value : new RubyHash
    {
        { "label", cell.Label },
        { "text", cell.Text },
        { "color", cell.Color },
        { "target", cell.Target },
        { "chips", cell.Chips == null ? RubyNil.Value : new RubyArray(cell.Chips.Select(chip => (RubyValue)chip)) },
        { "chip_colors", cell.ChipColors == null ? RubyNil.Value : new RubyArray(cell.ChipColors.Select(pair => (RubyValue)new RubyArray([pair.Key, pair.Value]))) },
    };

    /// <summary>
    /// Answers <see cref="Box"/>.
    /// </summary>
    /// <param name="screen">The screen's model.</param>
    /// <param name="rules">The rules the facts name.</param>
    /// <param name="request">The row's key and the kind of lines.</param>
    /// <returns>The lines, nil for a key the list lacks or a world the directory does not list.</returns>
    private static RubyValue? BoxValue(WorldScreen screen, ScreenRules rules, RubyHash request)
    {
        if (screen.Find(request["key"].AsText()) is not { View.Listed: { } listed } item)
        {
            return null;
        }

        IReadOnlyList<BoxLine> lines = request["kind"].AsText() switch
        {
            "players" => WorldScreenModel.PlayerLines(listed.Members, screen.FactsOf(item).Me),
            WorldScreenModel.WorldTarget => WorldScreenModel.WorldLines(item.View, listed, screen.FactsOf(item).Me, rules),
            WorldScreenModel.DataTarget => WorldScreenModel.DataLines(listed, screen.FactsOf(item)),
            _ => WorldScreenModel.ModLines(listed, screen.FactsOf(item)),
        };
        return new RubyArray(lines.Select(line => (RubyValue)(line.Kind == "head" ? new RubyArray([line.Kind, line.Text]) : new RubyArray([line.Kind, line.Text, line.Color, line.Note]))));
    }
}
