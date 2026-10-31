//----------------------------------------------------------------
//  ChatModel.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Game.Ruby;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Chat;

/// <summary>
/// The text in the open chat box as the chat sees it.
/// </summary>
/// <param name="Text">The text.</param>
/// <param name="Cursor">Where the cursor stands, in characters.</param>
/// <param name="Locked">Whether the box takes no typing but Escape, as on the help tab.</param>
public sealed record ChatBox(string Text, int Cursor, bool Locked);

/// <summary>
/// The chat of the open world: a line goes to every player of the world, to the party, to the
/// players on the same map or to one player, by the chat chosen; it shows in a bubble above the
/// sender and in the log, whose tabs show every chat or one. Commands at a line's start choose the
/// chat, whisper to a player or answer the last who whispered; the lines sent come back with Alt.
/// The box's typing, the log's wrap, scroll and clicks are the interface's.
/// </summary>
/// <remarks>
/// Its regular expressions read Ruby 1.9's ASCII classes and fold only A to Z, as the scripts did.
/// </remarks>
public sealed partial class ChatModel
{
    /// <summary>
    /// The global chat, to everyone in the world.
    /// </summary>
    public const string Global = "global";

    /// <summary>
    /// The map chat, to the players on the player's map.
    /// </summary>
    public const string Map = "map";

    /// <summary>
    /// The party chat, to the party's members.
    /// </summary>
    public const string Party = "party";

    /// <summary>
    /// The whisper chat, to one player.
    /// </summary>
    public const string Whisper = "whisper";

    /// <summary>
    /// The tab of every chat's lines.
    /// </summary>
    public const string All = "all";

    /// <summary>
    /// The help tab.
    /// </summary>
    public const string Help = "help";

    /// <summary>
    /// Characters a chat line may have.
    /// </summary>
    public const int MaxLength = 120;

    /// <summary>
    /// Chat lines kept for the log.
    /// </summary>
    public const int Kept = 50;

    /// <summary>
    /// Frames a chat line stays in the log, ten seconds, unless the chat box is open.
    /// </summary>
    public const int LogFrames = 600;

    /// <summary>
    /// Frames a bubble stays, six seconds.
    /// </summary>
    public const int BubbleFrames = 360;

    /// <summary>
    /// Lines sent that Alt with up and down bring back, kept for the session alone.
    /// </summary>
    public const int HistorySize = 20;

    /// <summary>
    /// Names the list of fitting names offers at most.
    /// </summary>
    public const int SuggestionCount = 5;

    /// <summary>
    /// What the relay's mirror says of a line of the global chat it dropped for coming too fast.
    /// </summary>
    public const int TooFast = 2;

    /// <summary>
    /// What the relay's mirror says of a line of the global chat it got.
    /// </summary>
    public const int Said = 1;

    /// <summary>
    /// The sound a whisper plays when it arrives while the chat box is closed: the game's recovery
    /// chime, which nothing on the map plays by itself.
    /// </summary>
    public const string WhisperSound = "recovery";

    /// <summary>
    /// What the log shows before a line an admin said from outside the game, through the relay.
    /// </summary>
    public const string AdminTag = "[Admin] ";

    /// <summary>
    /// The name the relay's own notices carry, which the log shows as a notice rather than an
    /// admin's line.
    /// </summary>
    public const string NoticeName = "MGQ Online";

    /// <summary>
    /// The seat the player's own bubble is kept under.
    /// </summary>
    public const int OwnSeat = -1;

    /// <summary>
    /// What starts the chat's lines in the log.
    /// </summary>
    private const string LogTag = "chat: ";

    /// <summary>
    /// Characters of a line the log writes at most, see <see cref="Short"/>.
    /// </summary>
    private const int ShortLength = 80;

    /// <summary>
    /// The chats a line goes to, in the order of their tabs; also the chats whose tab marks lines
    /// the player has not seen yet.
    /// </summary>
    public static readonly string[] Channels = [Global, Map, Party, Whisper];

    /// <summary>
    /// The log's tabs, in their order: all lines, then each chat's.
    /// </summary>
    public static readonly string[] Tabs = [All, Global, Map, Party, Whisper];

    /// <summary>
    /// What the help tab says.
    /// </summary>
    public static readonly string[] HelpText =
    [
        "A chat stays chosen until you choose another, by a command or a tab.",
        "/g <text>   Global: everyone in the world",
        "/m <text>   Map: the players on your map",
        "/p <text>   Party: your party only",
        "/w <name> <text>   Whisper: one player. Up and Down pick a name from the list, Enter or Tab takes it.",
        "/r <text>   Whisper back to the last player who whispered to you.",
        "Tabs: click one, or Alt with Left or Right. All shows every chat.",
        "Alt and a drag with the mouse move or resize the chat, Alt and a double click put it back.",
        "Alt with Up or Down brings back the lines you sent. Ctrl+V pastes.",
        "Up, Down, Page Up, Page Down and the mouse wheel scroll. Enter sends, Esc or the numpad's 0 closes.",
    ];

    /// <summary>
    /// What the tabs say.
    /// </summary>
    private static readonly Dictionary<string, string> TabNames = new(StringComparer.Ordinal)
    {
        [All] = "All",
        [Global] = "Global",
        [Map] = "Map",
        [Party] = "Party",
        [Whisper] = "Whisper",
        [Help] = "Help",
    };

    /// <summary>
    /// The commands that choose a chat, which holds for the lines after it until another is chosen.
    /// </summary>
    private static readonly Dictionary<string, string> Commands = new(StringComparer.Ordinal)
    {
        ["g"] = Global,
        ["global"] = Global,
        ["m"] = Map,
        ["map"] = Map,
        ["p"] = Party,
        ["party"] = Party,
    };

    /// <summary>
    /// The help tab's lines, which no other tab shows.
    /// </summary>
    private static readonly ChatLine[] HelpLines = [.. HelpText.Select(text => new ChatLine(null, text, Help, Help))];

    /// <summary>
    /// The room whose players the chat names and whose party it asks.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// What the chat reaches outside itself.
    /// </summary>
    private readonly IChatHost host;

    /// <summary>
    /// The log's lines, oldest first, <see cref="Kept"/> at most.
    /// </summary>
    private readonly List<ChatLine> log = [];

    /// <summary>
    /// Each sender's bubble, by their seat or <see cref="OwnSeat"/>, in the order they first spoke.
    /// </summary>
    private readonly List<ChatBubble> bubbles = [];

    /// <summary>
    /// The chats with lines the player has not seen.
    /// </summary>
    private readonly HashSet<string> unread = new(StringComparer.Ordinal);

    /// <summary>
    /// The lines sent, oldest first.
    /// </summary>
    private readonly List<string> history = [];

    /// <summary>
    /// The sent line a walk through them stands at, <see langword="null"/> outside a walk.
    /// </summary>
    private int? historyAt;

    /// <summary>
    /// What the chat box held before a walk through the lines sent began.
    /// </summary>
    private string? draft;

    /// <summary>
    /// The tab the help tab was opened from.
    /// </summary>
    private string? beforeHelp;

    /// <summary>
    /// The id of the player the whisper chat goes to, <see langword="null"/> before one was chosen.
    /// </summary>
    private string? whisperId;

    /// <summary>
    /// The last player who whispered to the player as their name and id.
    /// </summary>
    private (string Name, string? Id)? replyTo;

    /// <summary>
    /// The picked place in the list of fitting names.
    /// </summary>
    private int pick;

    /// <summary>
    /// The drain's frame, which ends a buzz and a chime once a frame.
    /// </summary>
    private long frame;

    /// <summary>
    /// The frame in which a refused character last buzzed.
    /// </summary>
    private long? buzzed;

    /// <summary>
    /// The frame in which a whisper last chimed.
    /// </summary>
    private long? chimed;

    /// <summary>
    /// Lines sent in the open world, for the log.
    /// </summary>
    private int sent;

    /// <summary>
    /// Lines received in the open world, for the log.
    /// </summary>
    private int received;

    /// <summary>
    /// Initializes the chat of a room.
    /// </summary>
    /// <param name="room">The world room.</param>
    /// <param name="host">What the chat reaches outside itself.</param>
    public ChatModel(WorldRoom room, IChatHost host)
    {
        this.room = room ?? throw new ArgumentNullException(nameof(room));
        this.host = host ?? throw new ArgumentNullException(nameof(host));
    }

    /// <summary>
    /// Gets the chat a line without a command goes to, one of <see cref="Channels"/>.
    /// </summary>
    public string Channel { get; private set; } = Global;

    /// <summary>
    /// Gets the log's picked tab.
    /// </summary>
    public string Tab { get; private set; } = All;

    /// <summary>
    /// Gets whom the whisper chat goes to, <see langword="null"/> before the player chose anyone.
    /// </summary>
    public string? WhisperTo { get; private set; }

    /// <summary>
    /// Gets the last player who whispered to the player, whom /r answers, by the name the log showed.
    /// </summary>
    public string? ReplyTo => replyTo?.Name;

    /// <summary>
    /// Gets a value indicating whether the Whisper tab shows: once the player whispered, got a
    /// whisper or chose the whisper chat, until the world closes.
    /// </summary>
    public bool WhisperTab { get; private set; }

    /// <summary>
    /// Gets the open chat box, <see langword="null"/> while it is closed.
    /// </summary>
    public ChatBox? Box { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the chat box is open.
    /// </summary>
    public bool Typing => Box is not null;

    /// <summary>
    /// Gets the lines sent, oldest first.
    /// </summary>
    public IReadOnlyList<string> History => history;

    /// <summary>
    /// Gets the bubbles above the senders, in the order they first spoke.
    /// </summary>
    public IReadOnlyList<ChatBubble> Bubbles => bubbles;

    /// <summary>
    /// Gets which of the fitting names Enter or Tab takes, its place in <see cref="Suggestions"/>.
    /// </summary>
    public int Pick => Math.Min(pick, Math.Max(Suggestions().Count - 1, 0));

    /// <summary>
    /// Lists the log's tabs: the Whisper tab once <see cref="WhisperTab"/> tells so, the help tab at
    /// the end while it is open.
    /// </summary>
    /// <returns>The tabs, in their order.</returns>
    public List<string> ShownTabs()
    {
        List<string> shown = [.. Tabs.Where(tab => WhisperTab || tab != Whisper)];
        if (Tab == Help)
        {
            shown.Add(Help);
        }

        return shown;
    }

    /// <summary>
    /// Lists the tabs with lines the player has not seen yet: lines of a chat that came while
    /// neither its tab nor All was picked.
    /// </summary>
    /// <returns>The tabs, in the order of <see cref="Channels"/>.</returns>
    public List<string> UnreadTabs() => [.. Channels.Where(unread.Contains)];

    /// <summary>
    /// Lists the log's lines its tab shows: all kept while the chat box is open, else the recent ones
    /// and the recent whispers, which the closed log shows whatever the tab; the help tab's own.
    /// </summary>
    /// <returns>The lines, oldest first.</returns>
    public IReadOnlyList<ChatLine> Entries()
    {
        if (Tab == Help)
        {
            return HelpLines;
        }

        return Typing ? [.. log.Where(line => line.ShownIn(Tab))] : [.. log.Where(line => line.Left > 0 && (line.ShownIn(Tab) || line.Channel == Whisper))];
    }

    /// <summary>
    /// Lists the names of the world's other players, whom the player may whisper to, numbered where
    /// several share one, as the room tells them apart.
    /// </summary>
    /// <returns>The names.</returns>
    public List<string> Names() => [.. room.Labels().Select(label => label.Label)];

    /// <summary>
    /// Lists the names that fit what follows the whisper command in the chat box.
    /// </summary>
    /// <returns>Up to <see cref="SuggestionCount"/> names, by the alphabet; none without the command
    /// and a character after it.</returns>
    public List<string> Suggestions()
    {
        if (Box is null || Tab == Help || WhisperTyped().Match(Box.Text) is not { Success: true } match)
        {
            return [];
        }

        string start = RubyAscii.Downcase(match.Groups[1].Value);
        List<string> fitting = [.. Names().Where(name => RubyAscii.Downcase(name).StartsWith(start, StringComparison.Ordinal))];
        fitting.Sort((one, other) => string.CompareOrdinal(RubyAscii.Downcase(one), RubyAscii.Downcase(other)));
        return [.. fitting.Take(SuggestionCount)];
    }

    /// <summary>
    /// Opens the chat box.
    /// </summary>
    /// <param name="byKey">Whether its hotkey opened it, rather than the action wheel.</param>
    /// <param name="scene">The scene it opens in, for the log.</param>
    public void Open(bool byKey, string scene)
    {
        Box = new ChatBox(string.Empty, 0, false);
        historyAt = null;
        draft = null;
        Log($"chat box opened {(byKey ? "with its key" : "from the action wheel")} in {scene}");
    }

    /// <summary>
    /// Closes the chat box, if it is open, leaving the help tab.
    /// </summary>
    /// <param name="reason">Why, for the log; <see langword="null"/> for none.</param>
    public void Close(string? reason)
    {
        if (Box is null)
        {
            return;
        }

        Box = null;
        LeaveHelp();
        Log($"chat box closed{(reason is null ? string.Empty : ": " + reason)}");
    }

    /// <summary>
    /// Takes what the box holds after typing, and a command typed at its start: /help and a space
    /// opens the help tab, a chat's command and a space chooses that chat, the box keeping what
    /// follows the command.
    /// </summary>
    /// <param name="text">The box's text.</param>
    /// <param name="cursor">Where its cursor stands.</param>
    public void Typed(string text, int cursor)
    {
        ArgumentNullException.ThrowIfNull(text);
        if (Box is null)
        {
            return;
        }

        Edit(text, cursor);
        pick = 0;
        if (HelpCommand().IsMatch(text) && EndsInSpace().IsMatch(text))
        {
            OpenHelp();
            return;
        }

        if (TakeCommand(text, false) is { } rest)
        {
            Edit(rest, Box.Cursor - (text.Length - rest.Length));
        }
    }

    /// <summary>
    /// Takes Enter: the picked name of the list, else the help tab for /help, else the line sent.
    /// </summary>
    public void Enter()
    {
        if (Box is null || TakeSuggestion())
        {
            return;
        }

        if (HelpCommand().IsMatch(RubyAscii.Strip(Box.Text)))
        {
            OpenHelp();
            return;
        }

        SendTyped();
    }

    /// <summary>
    /// Takes Escape, which closes the chat box.
    /// </summary>
    public void Escape()
    {
        Close("Escape");
        host.Sound("cancel");
    }

    /// <summary>
    /// Buzzes for a character the box refused, once a frame, so a paste longer than the box takes
    /// buzzes once.
    /// </summary>
    public void Refused()
    {
        if (buzzed != frame)
        {
            host.Sound("buzzer");
        }

        buzzed = frame;
    }

    /// <summary>
    /// Follows the arrows with the left Alt: right picks the next tab and left the one before, round
    /// the tabs; up and down bring back the lines sent, except on the help tab.
    /// </summary>
    /// <param name="tabStep">1 for right, -1 for left, 0 for neither or both.</param>
    /// <param name="lineStep">1 for down, -1 for up, 0 for neither or both.</param>
    public void Alt(int tabStep, int lineStep)
    {
        if (tabStep != 0)
        {
            List<string> shown = ShownTabs();
            int at = shown.IndexOf(Tab) + tabStep;
            SelectTab(shown[((at % shown.Count) + shown.Count) % shown.Count], "with Alt and the arrows");
        }

        if (lineStep != 0 && Tab != Help)
        {
            WalkHistory(lineStep);
        }
    }

    /// <summary>
    /// Moves the pick through the list of fitting names, while it shows.
    /// </summary>
    /// <param name="step">1 for down, -1 for up.</param>
    public void MovePick(int step)
    {
        int count = Suggestions().Count;
        if (step == 0 || count == 0)
        {
            return;
        }

        pick = Math.Min(Math.Max(Pick + step, 0), count - 1);
        host.Sound("cursor");
    }

    /// <summary>
    /// Takes the picked name of the list for the whisper chat, emptying the box.
    /// </summary>
    /// <returns>Whether a name was there to take.</returns>
    public bool TakeSuggestion()
    {
        List<string> names = Suggestions();
        if (names.Count == 0)
        {
            return false;
        }

        ChooseWhisper(names[Pick], Named(names[Pick]));
        Edit(string.Empty, 0);
        host.Sound("ok");
        return true;
    }

    /// <summary>
    /// Picks a tab of the log. A chat's tab also chooses that chat for the lines after it.
    /// </summary>
    /// <param name="tab">The tab, one of <see cref="ShownTabs"/>.</param>
    /// <param name="how">How it was picked, for the log.</param>
    public void SelectTab(string tab, string how)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (tab == Tab)
        {
            return;
        }

        Tab = tab;
        if (Channels.Contains(tab, StringComparer.Ordinal))
        {
            Channel = tab;
        }

        host.Sound("cursor");
        Log($"picked the {TabNames[tab]} tab {how}, lines go to the {TabNames[Channel]} chat");
    }

    /// <summary>
    /// Chooses whom the whisper chat goes to, and the whisper chat, keeping the player by their id,
    /// since the numbers of a name that several share change as they come and go.
    /// </summary>
    /// <param name="name">Their name as <see cref="Names"/> tells it.</param>
    /// <param name="peer">The player, <see langword="null"/> when nobody has that name.</param>
    public void ChooseWhisper(string name, Peer? peer)
    {
        WhisperTo = name;
        whisperId = peer?.Id;
        Choose(Whisper);
    }

    /// <summary>
    /// Adds a line of the game's own to the log, such as a player leaving a battle.
    /// </summary>
    /// <param name="text">The line.</param>
    public void GameLine(string text)
    {
        Log($"game line: {Short(text)}");
        Push(new ChatLine(null, text, "system", null));
    }

    /// <summary>
    /// Takes another player's line of the global or the map chat, or an admin's that the relay said.
    /// A line of the map chat said on another map is dropped; the sender's map comes with the line,
    /// since their last state may lag behind or run ahead of it.
    /// </summary>
    /// <param name="peer">Who sent it, <see langword="null"/> before their first state or for the relay.</param>
    /// <param name="message">The message, the line under "chat", "ch" "say" for the map chat with
    /// the sender's map under "map".</param>
    /// <param name="relay">Whether the relay pushed it, which marks an admin's line.</param>
    public void Receive(Peer? peer, WorldFields message, bool relay)
    {
        ArgumentNullException.ThrowIfNull(message);
        string channel = message["ch"] == "say" ? Map : Global;
        if (channel == Map && !(message.Text("map").Length > 0 && WorldFields.ToI(message["map"]) == room.OwnMap))
        {
            Log($"dropped a map line from {(peer is null ? message.Text("name") : peer.ToString())}, said on map {message["map"] ?? "?"}");
            return;
        }

        TakeLine(peer, message["chat"], message["name"], channel, relay);
    }

    /// <summary>
    /// Takes a party member's line of the party chat, past the party's gate.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message, the line under "pchat".</param>
    public void ReceiveParty(Peer? peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(message);
        TakeLine(peer, message["pchat"], message["name"], Party, false);
    }

    /// <summary>
    /// Takes a line another player whispered to the player alone.
    /// </summary>
    /// <param name="peer">Who sent it, <see langword="null"/> before their first state.</param>
    /// <param name="message">The message, the line under "whisper".</param>
    public void ReceiveWhisper(Peer? peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(message);
        TakeLine(peer, message["whisper"], message["name"], Whisper, false);
    }

    /// <summary>
    /// Takes the chat's messages through the room's routes: the global, the map and the whisper chat
    /// straight, the party chat past the party's gate.
    /// </summary>
    public void Listen()
    {
        room.Take("chat", RouteGate.None, (peer, message, _, relay) => Receive(peer, message, relay));
        room.Take("whisper", RouteGate.None, (peer, message, _) => ReceiveWhisper(peer, message));
        room.Take("pchat", RouteGate.Party, ReceiveParty);
    }

    /// <summary>
    /// Runs one frame: closes the chat box in a scene it does not open in, takes the picked tab's
    /// lines as seen, and lets lines and bubbles run out; once no world is open it forgets the chat.
    /// </summary>
    /// <param name="inWorld">Whether a world is open.</param>
    /// <param name="chatScene">Whether the scene in front is one the chat box opens in.</param>
    /// <param name="scene">The scene in front, for the log.</param>
    /// <param name="now">The drain's frame.</param>
    public void Tick(bool inWorld, bool chatScene, string scene, long now)
    {
        frame = now;
        if (!(inWorld && chatScene))
        {
            Close($"{scene} shows, where the chat does not open");
        }

        if (Tab == All)
        {
            unread.Clear();
        }
        else
        {
            unread.Remove(Tab);
        }

        if (inWorld)
        {
            CountDown();
        }
        else
        {
            Reset();
        }
    }

    /// <summary>
    /// Forgets the log, the bubbles and the lines sent and closes the box, as when the world closes;
    /// the next world starts in the global chat on the All tab without the Whisper tab.
    /// </summary>
    public void Reset()
    {
        Close("no world is open");
        if (log.Count > 0)
        {
            Log($"forgot {log.Count} chat lines as the world closed ({sent} sent, {received} received)");
        }

        log.Clear();
        bubbles.Clear();
        unread.Clear();
        history.Clear();
        WhisperTo = null;
        whisperId = null;
        replyTo = null;
        WhisperTab = false;
        Channel = Global;
        Tab = All;
        beforeHelp = null;
        sent = 0;
        received = 0;
    }

    /// <summary>
    /// Writes a line for the log as the scripts' log shortens it: on one line, cut to
    /// <see cref="ShortLength"/> characters with "..." at the end.
    /// </summary>
    /// <param name="text">The line.</param>
    /// <returns>The line for the log.</returns>
    internal static string Short(string text)
    {
        string line = LineEnds().Replace(text, " ");
        return Length(line) > ShortLength ? Cut(line, ShortLength - 3) + "..." : line;
    }

    /// <summary>
    /// Counts the characters of a text, as Ruby counts a UTF-8 string's.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The characters.</returns>
    internal static int Length(string text)
    {
        int count = 0;
        foreach (Rune _ in text.EnumerateRunes())
        {
            count++;
        }

        return count;
    }

    /// <summary>
    /// Keeps the first characters of a text, as Ruby's <c>text[0, count]</c> does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="count">The characters kept at most.</param>
    /// <returns>The text kept.</returns>
    internal static string Cut(string text, int count)
    {
        var kept = new StringBuilder();
        foreach (Rune rune in text.EnumerateRunes().Take(count))
        {
            kept.Append(rune.ToString());
        }

        return kept.ToString();
    }

    /// <summary>
    /// What a player's or an admin's line loses: control characters and the line and paragraph
    /// separators, which would break the line in the log.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("[\\x00-\\x1F\\x7F-\\x9F\\u2028\\u2029]", RegexOptions.CultureInvariant)]
    private static partial Regex LineBreakers();

    /// <summary>
    /// A command at the start of a line, its name in the first group, the white space after it in
    /// the second.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("\\A/([a-zA-Z]+)([ \\t\\n\\f\\r]+|\\z)", RegexOptions.CultureInvariant)]
    private static partial Regex Command();

    /// <summary>
    /// The command that whispers to one player, their name after it.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("\\A/([wW]|[wW][hH][iI][sS][pP][eE][rR])([ \\t\\n\\f\\r]+|\\z)", RegexOptions.CultureInvariant)]
    private static partial Regex WhisperCommand();

    /// <summary>
    /// The whisper command with the start of a name typed, which offers the names that fit.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("\\A/(?:[wW]|[wW][hH][iI][sS][pP][eE][rR]) +([^ \\t\\n\\f\\r].*)\\z", RegexOptions.CultureInvariant)]
    private static partial Regex WhisperTyped();

    /// <summary>
    /// The command that answers the last player who whispered to the player.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("\\A/[rR]([ \\t\\n\\f\\r]+|\\z)", RegexOptions.CultureInvariant)]
    private static partial Regex ReplyCommand();

    /// <summary>
    /// The command that opens the help tab.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("\\A/[hH][eE][lL][pP]([ \\t\\n\\f\\r]|\\z)", RegexOptions.CultureInvariant)]
    private static partial Regex HelpCommand();

    /// <summary>
    /// A text that ends in white space.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("[ \\t\\n\\f\\r]\\z", RegexOptions.CultureInvariant)]
    private static partial Regex EndsInSpace();

    /// <summary>
    /// A white space character.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("\\A[ \\t\\n\\f\\r]", RegexOptions.CultureInvariant)]
    private static partial Regex StartsWithSpace();

    /// <summary>
    /// Line breaks, which the log writes as one space.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("[\\r\\n]+", RegexOptions.CultureInvariant)]
    private static partial Regex LineEnds();

    /// <summary>
    /// Writes a line of the chat into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => host.Log(LogTag + line);

    /// <summary>
    /// Replaces the box's text and puts its cursor, kept within the text.
    /// </summary>
    /// <param name="text">The new text.</param>
    /// <param name="cursor">The cursor's new place.</param>
    private void Edit(string text, int cursor)
    {
        if (Box is not null)
        {
            Box = Box with { Text = text, Cursor = Math.Min(Math.Max(cursor, 0), Length(text)) };
        }
    }

    /// <summary>
    /// Opens the help tab, which the chat box only reads in.
    /// </summary>
    private void OpenHelp()
    {
        if (Tab != Help)
        {
            beforeHelp = Tab;
        }

        Tab = Help;
        Edit(string.Empty, 0);
        Box = Box! with { Locked = true };
        host.Sound("ok");
        Log("opened the help tab");
    }

    /// <summary>
    /// Leaves the help tab for the tab it was opened from.
    /// </summary>
    private void LeaveHelp()
    {
        if (Tab != Help)
        {
            return;
        }

        Tab = beforeHelp ?? All;
        if (Box is not null)
        {
            Box = Box with { Locked = false };
        }
    }

    /// <summary>
    /// Chooses the chat for the lines after it. The log follows to its tab unless it shows all lines.
    /// </summary>
    /// <param name="channel">One of <see cref="Channels"/>.</param>
    private void Choose(string channel)
    {
        if (channel == Whisper)
        {
            WhisperTab = true;
        }

        Channel = channel;
        if (Tab != All)
        {
            Tab = channel;
        }

        Log($"chose the {TabNames[channel]} chat");
    }

    /// <summary>
    /// Takes a command that chooses a chat from the start of a text.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="ended">Whether the text is complete, so a command needs no space after it.</param>
    /// <returns>The text after the command, <see langword="null"/> when it starts with none.</returns>
    private string? TakeCommand(string text, bool ended)
    {
        Match match = Command().Match(text);
        if (!match.Success || !Commands.TryGetValue(RubyAscii.Downcase(match.Groups[1].Value), out string? channel) || !(ended || match.Groups[2].Length > 0))
        {
            return null;
        }

        Choose(channel);
        return text[match.Length..];
    }

    /// <summary>
    /// Keeps a line the player sent for Alt with up and down, unless it repeats the last one, and
    /// forgets the oldest beyond <see cref="HistorySize"/>. Also ends a walk through the lines.
    /// </summary>
    /// <param name="text">The line as typed, commands included.</param>
    private void RememberSent(string text)
    {
        historyAt = null;
        draft = null;
        if (text.Length == 0 || (history.Count > 0 && history[^1] == text))
        {
            return;
        }

        history.Add(text);
        if (history.Count > HistorySize)
        {
            history.RemoveAt(0);
        }
    }

    /// <summary>
    /// Brings a line sent back into the chat box: up the one before, down the one after, and past
    /// the newest what the box held before the walk began. It stays at the oldest and at the draft.
    /// </summary>
    /// <param name="step">-1 for the line before, 1 for the one after.</param>
    private void WalkHistory(int step)
    {
        if (history.Count == 0)
        {
            Log("no line sent to bring back");
            return;
        }

        int at = historyAt ?? history.Count;
        int to = Math.Min(Math.Max(at + step, 0), history.Count);
        if (to == at)
        {
            return;
        }

        if (historyAt is null)
        {
            draft = Box?.Text;
        }

        historyAt = to == history.Count ? null : to;
        string text = historyAt is null ? draft ?? string.Empty : history[to];
        Edit(text, Length(text));
        host.Sound("cursor");
        Log(historyAt is null ? "back at the line being typed" : $"brought back sent line {to + 1} of {history.Count}");
    }

    /// <summary>
    /// Sends the chat box's text to the chosen chat, closing the box; an empty box just closes. A
    /// command at its start chooses the chat first, for this line and the ones after it, /r the
    /// whisper chat to the last player who whispered, refused once they left as /w is.
    /// </summary>
    private void SendTyped()
    {
        string text = RubyAscii.Strip(Box!.Text);
        RememberSent(text);
        Close("Enter");
        Match command = WhisperCommand().Match(text);
        Match reply = ReplyCommand().Match(text);
        if (command.Success)
        {
            string rest = text[command.Length..];
            if (NamedIn(rest) is not { } name)
            {
                Refuse(rest.Length == 0 ? "Type a name after /w to whisper to them." : $"Nobody called {FirstWord(rest)} is in the world.");
                return;
            }

            ChooseWhisper(name, Named(name));
            text = rest[name.Length..];
        }
        else if (reply.Success)
        {
            if (replyTo is not { } answered)
            {
                Refuse("Nobody has whispered to you yet.");
                return;
            }

            if (PlayerOf(answered.Name, answered.Id) is not { } peer)
            {
                Refuse($"{answered.Name} is not in the world.");
                return;
            }

            Log($"/r answers {answered.Name}");
            ChooseWhisper(LabelOf(peer) ?? answered.Name, peer);
            text = text[reply.Length..];
        }
        else
        {
            text = TakeCommand(text, true) ?? text;
        }

        text = RubyAscii.Strip(text);
        if (text.Length == 0)
        {
            return;
        }

        string channel = Channel;
        if (channel == Party && !InParty)
        {
            Refuse("You are not in a party.");
            return;
        }

        if (channel == Whisper && WhisperTo is null)
        {
            Refuse("Type /w and a name to choose whom to whisper to.");
            return;
        }

        string own = room.NameOf(room.OwnId);
        bool? went = SendLine(channel, text);
        if (went is null)
        {
            return;
        }

        if (went == false)
        {
            Refuse(channel == Whisper ? $"{WhisperTo} is not in the world." : "The message could not be sent.");
            return;
        }

        sent++;
        Log($"sent to the {TabNames[channel]} chat{(channel == Whisper ? " of " + WhisperTo : string.Empty)} (line {sent} sent): {ShownInLog(text, channel)}");
        Add(OwnSeat, own, text, channel, false, false, channel == Whisper ? WhisperTo : null, null);
    }

    /// <summary>
    /// Sends a line to a chat, which turns a line of the global chat down when it comes too fast.
    /// </summary>
    /// <param name="channel">The chat.</param>
    /// <param name="text">The line.</param>
    /// <returns>Whether it went out, <see langword="null"/> when it came too fast and was turned down.</returns>
    private bool? SendLine(string channel, string text)
    {
        int? seat = null;
        if (channel == Whisper)
        {
            if (WhisperPeer() is not { } peer)
            {
                return false;
            }

            seat = peer.Seat;
        }

        if (channel == Map)
        {
            Log($"{room.Peers.Count(peer => peer.Present && WorldFields.ToI(peer.State["map"]) == room.OwnMap)} other players on map {room.OwnMap} hear the map chat");
        }

        (bool went, int said) = host.Send(channel, text, seat, room.OwnMap);
        if (said == TooFast)
        {
            Refuse("You are sending too fast. Wait a moment, then send the line again.");
            return null;
        }

        if (channel == Global && said != Said)
        {
            Log("the relay did not take the line for the world's chat");
        }

        return went;
    }

    /// <summary>
    /// Writes a line for the log, leaving a whisper's text out.
    /// </summary>
    /// <param name="text">The line.</param>
    /// <param name="channel">Its chat.</param>
    /// <returns>What the log says of it.</returns>
    private static string ShownInLog(string text, string channel) =>
        channel == Whisper ? $"({Length(text).ToString(CultureInfo.InvariantCulture)} characters, not logged)" : Short(text);

    /// <summary>
    /// Finds the first word of a text, split at ASCII white space.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The word, empty for none.</returns>
    private static string FirstWord(string text)
    {
        string stripped = RubyAscii.Strip(text);
        int end = 0;
        while (end < stripped.Length && !(stripped[end] < 0x80 && RubyAscii.IsSpace((byte)stripped[end])))
        {
            end++;
        }

        return stripped[..end];
    }

    /// <summary>
    /// Turns a line down that cannot be sent, with a notice.
    /// </summary>
    /// <param name="text">Why.</param>
    private void Refuse(string text)
    {
        Log($"did not send the line: {text}");
        host.Sound("buzzer");
        room.Notice(text);
    }

    /// <summary>
    /// Finds the player the whisper chat goes to, and names them as the names list does now.
    /// </summary>
    /// <returns>The player, <see langword="null"/> once they left the world.</returns>
    private Peer? WhisperPeer()
    {
        if (PlayerOf(WhisperTo, whisperId) is not { } peer)
        {
            return null;
        }

        WhisperTo = LabelOf(peer) ?? WhisperTo;
        return peer;
    }

    /// <summary>
    /// Finds a player by their id, or by their name for one who had no state yet when they were
    /// seen. A known id never falls back to the name, which another player may bear by now.
    /// </summary>
    /// <param name="name">Their name as the log shows it.</param>
    /// <param name="id">Their player id, <see langword="null"/> or empty for none.</param>
    /// <returns>The player, <see langword="null"/> once they left the world.</returns>
    private Peer? PlayerOf(string? name, string? id) =>
        string.IsNullOrEmpty(id) ? Named(name) : room.Peers.FirstOrDefault(peer => peer.Present && peer.Id == id);

    /// <summary>
    /// Finds a player whose connection stands by the name that tells them apart.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The player, <see langword="null"/> when nobody present has that name.</returns>
    private Peer? Named(string? name) =>
        string.IsNullOrEmpty(name) ? null : room.Labels().Find(label => label.Label == name).Peer;

    /// <summary>
    /// Tells the name that tells a player apart.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>The name, <see langword="null"/> once their connection is down or for a nameless player.</returns>
    private string? LabelOf(Peer peer) => room.Labels().Find(label => label.Peer == peer).Label;

    /// <summary>
    /// Finds the player a whisper command names at the start of a text, the longest name that fits.
    /// </summary>
    /// <param name="text">What follows the command.</param>
    /// <returns>Their name, <see langword="null"/> when no player's name starts the text.</returns>
    private string? NamedIn(string text)
    {
        string folded = RubyAscii.Downcase(text);
        return Names().OrderByDescending(name => name.Length).FirstOrDefault(name =>
            folded.StartsWith(RubyAscii.Downcase(name), StringComparison.Ordinal) && (text.Length == name.Length || StartsWithSpace().IsMatch(text[name.Length..])));
    }

    /// <summary>
    /// Gets a value indicating whether the player is in a party with someone else in it.
    /// </summary>
    private bool InParty => room.InWorld && room.Party.InParty;

    /// <summary>
    /// Adds another player's line, without the line breakers and cut to <see cref="MaxLength"/>,
    /// under the name that tells them apart.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="line">The line.</param>
    /// <param name="name">The name the message carries, for a sender without a state yet or an admin.</param>
    /// <param name="channel">Its chat.</param>
    /// <param name="admin">Whether an admin said it through the relay, from outside the game.</param>
    private void TakeLine(Peer? peer, string? line, string? name, string channel, bool admin)
    {
        string text = Cut(RubyAscii.Strip(LineBreakers().Replace(line ?? string.Empty, string.Empty)), MaxLength);
        string sender = peer?.ToString() ?? (admin ? $"the admin {name} through the relay" : $"{name} (no state yet, no bubble)");
        if (text.Length == 0)
        {
            Log($"dropped an empty {TabNames[channel]} line from {sender}");
            return;
        }

        if (admin && name == NoticeName)
        {
            Notice(text);
            return;
        }

        received++;
        Log($"{TabNames[channel]} line from {sender} (line {received} received): {ShownInLog(text, channel)}");
        string? id = peer is not null && peer.Id.Length > 0 ? peer.Id : null;
        string? shown = peer is null ? name : LabelOf(peer) ?? peer.State["name"];
        Add(peer?.Seat, shown, text, channel, peer is not null && InParty && room.Party.IsMember(peer.State), admin, null, id);
        if (channel == Whisper)
        {
            Whispered(shown ?? string.Empty, id);
        }
    }

    /// <summary>
    /// Takes note of a whisper that arrived: its sender is whom /r answers, and while the chat box is
    /// closed the whisper's sound calls the player's attention, once a frame.
    /// </summary>
    /// <param name="name">The sender's name as the log shows it.</param>
    /// <param name="id">The sender's player id, <see langword="null"/> without a state yet.</param>
    private void Whispered(string name, string? id)
    {
        if (name.Length > 0)
        {
            replyTo = (name, id);
        }

        if (Typing || chimed == frame)
        {
            return;
        }

        chimed = frame;
        host.Sound(WhisperSound);
        Log($"played play_{WhisperSound} for the whisper, the chat box being closed");
    }

    /// <summary>
    /// Adds a notice of the relay's own to every tab of the log, red between slashes, and to the
    /// notification box.
    /// </summary>
    /// <param name="text">The notice.</param>
    private void Notice(string text)
    {
        Log($"relay notice: {text}");
        Push(new ChatLine(null, $"// {text} //", "notice", null));
        host.Announce(text);
    }

    /// <summary>
    /// Adds a chat line to the log, and to the sender's bubble. A whisper shows the Whisper tab.
    /// </summary>
    /// <param name="seat">The sender's seat, <see cref="OwnSeat"/> for the player, <see langword="null"/> for no bubble.</param>
    /// <param name="name">The sender's name.</param>
    /// <param name="text">The line.</param>
    /// <param name="channel">Its chat.</param>
    /// <param name="member">Whether another sender is in the player's party.</param>
    /// <param name="admin">Whether an admin said it through the relay.</param>
    /// <param name="to">Whom the player whispered it to.</param>
    /// <param name="id">Another sender's player id, for their menu.</param>
    private void Add(int? seat, string? name, string text, string channel, bool member, bool admin, string? to, string? id)
    {
        string who = seat == OwnSeat ? "me" : admin ? "admin" : member ? "member" : "other";
        if (channel == Whisper)
        {
            WhisperTab = true;
        }

        Push(new ChatLine(name ?? string.Empty, text, who, channel, to, id));
        if (seat is { } speaker)
        {
            int at = bubbles.FindIndex(bubble => bubble.Seat == speaker);
            var bubble = new ChatBubble(speaker, text, channel) { Left = BubbleFrames };
            if (at < 0)
            {
                bubbles.Add(bubble);
            }
            else
            {
                bubbles[at] = bubble;
            }
        }

        if (seat != OwnSeat && Tab != channel && Tab != All)
        {
            unread.Add(channel);
        }
    }

    /// <summary>
    /// Adds a line to the log, forgetting the oldest beyond <see cref="Kept"/>.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Push(ChatLine line)
    {
        line.Left = LogFrames;
        log.Add(line);
        if (log.Count > Kept)
        {
            log.RemoveAt(0);
        }
    }

    /// <summary>
    /// Lets log lines and bubbles run out by a frame.
    /// </summary>
    private void CountDown()
    {
        foreach (ChatLine line in log.Where(line => line.Left > 0))
        {
            line.Left--;
        }

        foreach (ChatBubble bubble in bubbles)
        {
            bubble.Left--;
        }

        bubbles.RemoveAll(bubble => bubble.Left <= 0);
    }
}
