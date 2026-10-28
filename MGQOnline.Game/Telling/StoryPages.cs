//----------------------------------------------------------------
//  StoryPages.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Scene;

namespace MGQOnline.Game.Telling;

/// <summary>
/// A page of a story's dialogue as the message window shows it.
/// </summary>
/// <param name="Face">The face's file, "" for none.</param>
/// <param name="Index">The face's place in its file.</param>
/// <param name="Background">The window's background.</param>
/// <param name="Position">The window's position.</param>
/// <param name="Lines">The page's lines.</param>
/// <param name="Choices">The choices it offers, none for a plain page.</param>
public sealed record StoryPage(string Face, int Index, int Background, int Position, IReadOnlyList<string> Lines, IReadOnlyList<string> Choices);

/// <summary>
/// A page of the player's story that a teller shows, see <see cref="StoryPages.Show"/>.
/// </summary>
/// <param name="Id">The page's id.</param>
/// <param name="Page">The page.</param>
/// <param name="Told">Whether it goes to the viewers now; false while it is kept, as the player skips.</param>
/// <param name="Skipped">The pages kept before it that it replaced and that never went out, when told.</param>
public sealed record PageShown(string Id, StoryPage Page, bool Told, int Skipped);

/// <summary>
/// A page a teller kept while the player skipped, which goes out now, see <see cref="StoryPages.Flush"/>.
/// </summary>
/// <param name="Id">The page's id.</param>
/// <param name="Page">The page.</param>
/// <param name="Skipped">The pages kept before it that it replaced and that never went out.</param>
/// <param name="Passed">Whether the player moved past it, which goes out with it.</param>
public sealed record PageTold(string Id, StoryPage Page, int Skipped, bool Passed);

/// <summary>
/// A page of another player's story the viewer heard, waiting to show.
/// </summary>
/// <param name="Id">The page's id.</param>
/// <param name="Face">The face's file.</param>
/// <param name="Index">The face's place in its file.</param>
/// <param name="Background">The window's background.</param>
/// <param name="Position">The window's position.</param>
/// <param name="Lines">The lines it shows, its choices written as one more line.</param>
public sealed record HeardPage(string Id, string Face, int Index, int Background, int Position, IReadOnlyList<string> Lines);

/// <summary>
/// What a viewer does with the pages waiting once the player is free, see <see cref="StoryPages.Next"/>.
/// </summary>
/// <param name="Show">The page to show now, <see langword="null"/> for none.</param>
/// <param name="Skipped">The pages the teller moved past that were left out, to stay a few pages behind at most.</param>
/// <param name="Passed">The pages the teller moved past that were left out, since something waits for the player.</param>
/// <param name="Dropped">The pages dropped, since the player shares no story any more.</param>
public sealed record PagesNext(HeardPage? Show, IReadOnlyList<string> Skipped, IReadOnlyList<string> Passed, int Dropped);

/// <summary>
/// Whether the page of another player's story the message window holds is over, see
/// <see cref="StoryPages.Over"/>.
/// </summary>
/// <param name="Over">Whether it is.</param>
/// <param name="Reason">Why, the first time it is over; <see langword="null"/> afterwards and while it holds.</param>
public sealed record PageOver(bool Over, string? Reason);

/// <summary>
/// The pages of a story's dialogue as coop_events.rbx kept them, by frame. The teller's side names
/// each page shown (a session id and a count) and tells it to the viewers, but while the player
/// holds the game's skip, which passes a page every frame, only one page every
/// <see cref="SkipSendFrames"/>, the last, keeping the one between, which <see cref="Flush"/> tells
/// later. The viewer's side keeps the pages heard until the player is free, at most
/// <see cref="MaxHeard"/>, shows them one by one, leaves out the oldest the teller moved past while
/// more than <see cref="CatchUpPages"/> wait, and holds the shown page until it is over: the teller
/// moved past it and the player had the time to read it, or the telling ended.
/// </summary>
public sealed class StoryPages
{
    /// <summary>
    /// Pages of another player's story kept at most while the player is busy.
    /// </summary>
    public const int MaxHeard = 30;

    /// <summary>
    /// Pages of another player's story a viewer remembers the teller moved past, at most.
    /// </summary>
    public const int MaxDone = 64;

    /// <summary>
    /// Pages a viewer may fall behind by: past them, the oldest the teller moved past are left out,
    /// so the viewer never lags far behind the scene.
    /// </summary>
    public const int CatchUpPages = 3;

    /// <summary>
    /// Frames a page stays at least once the teller moved past it, before its characters count;
    /// confirm moves on sooner.
    /// </summary>
    public const int ReadFrames = 60;

    /// <summary>
    /// Frames a page stays longer per character, see <see cref="ReadFrames"/>.
    /// </summary>
    public const int ReadFramesPerCharacter = 2;

    /// <summary>
    /// Frames a page stays at most once the teller moved past it.
    /// </summary>
    public const int MostReadFrames = 180;

    /// <summary>
    /// Frames a page of a Classic leader's story stays after the leader's state stopped saying they
    /// tell the story, before the viewer's game ends it anyway.
    /// </summary>
    public const int StaleFrames = 120;

    /// <summary>
    /// Frames between two pages a teller tells while holding the game's skip; the scene's changes
    /// keep the same pace.
    /// </summary>
    public const int SkipSendFrames = SceneQueue.SkipSendFrames;

    /// <summary>
    /// Makes the id of the teller's session, which page ids start with.
    /// </summary>
    private readonly Func<string> _newSession;

    /// <summary>
    /// The pages heard waiting to show, the oldest first.
    /// </summary>
    private readonly List<HeardPage> _heard = [];

    /// <summary>
    /// The pages the teller moved past, the oldest first.
    /// </summary>
    private readonly List<string> _done = [];

    /// <summary>
    /// The teller's session, <see langword="null"/> before the first page.
    /// </summary>
    private string? _session;

    /// <summary>
    /// The count of the teller's pages.
    /// </summary>
    private int _page;

    /// <summary>
    /// The lines and choices of the page the teller's window shows, <see langword="null"/> once it passed.
    /// </summary>
    private StoryPage? _shown;

    /// <summary>
    /// The page the teller keeps while the player skips, <see langword="null"/> for none.
    /// </summary>
    private PageTold? _kept;

    /// <summary>
    /// The pages kept and replaced since the last page told.
    /// </summary>
    private int _skipped;

    /// <summary>
    /// The frame the teller last told a page at, <see langword="null"/> for none in this telling.
    /// </summary>
    private long? _toldAt;

    /// <summary>
    /// The page the teller told whose end is still to tell, <see langword="null"/> for none.
    /// </summary>
    private string? _toldPage;

    /// <summary>
    /// The page the viewer's window holds: its id, the frame it showed at, its reading time and
    /// whether its end was reported; <see langword="null"/> for none.
    /// </summary>
    private (string Id, long Since, int Read, bool Over)? _mirrored;

    /// <summary>
    /// Creates the pages of a context.
    /// </summary>
    /// <param name="newSession">Makes the id of the teller's session.</param>
    public StoryPages(Func<string> newSession)
    {
        ArgumentNullException.ThrowIfNull(newSession);
        _newSession = newSession;
    }

    /// <summary>
    /// Gets how many pages heard wait to show.
    /// </summary>
    public int Waiting => _heard.Count;

    /// <summary>
    /// Gets whether the viewer's window holds a page of another player's story.
    /// </summary>
    public bool Mirroring => _mirrored is not null;

    /// <summary>
    /// Takes a page the teller's story shows: a new one gets an id and goes to the viewers, but
    /// while the player holds the game's skip within <see cref="SkipSendFrames"/> of the last page
    /// told it is kept instead, replacing the one kept before.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="skipHeld">Whether the player holds the game's skip.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>The page, <see langword="null"/> for an empty page or the one shown already.</returns>
    public PageShown? Show(StoryPage page, bool skipHeld, long frame)
    {
        ArgumentNullException.ThrowIfNull(page);
        if ((page.Lines.Count == 0 && page.Choices.Count == 0) || (_shown is { } shown && Same(shown, page)))
        {
            return null;
        }

        _shown = page;
        _page++;
        string id = PageId();
        if (_kept is not null)
        {
            _skipped++;
        }

        _kept = null;
        if (skipHeld && _toldAt is { } told && !Past(told, SkipSendFrames, frame))
        {
            _kept = new PageTold(id, page, 0, false);
            return new PageShown(id, page, false, 0);
        }

        return new PageShown(id, page, true, Tell(id, frame));
    }

    /// <summary>
    /// Takes that the teller moved past the page their story showed: a page told has its end told,
    /// the page kept is marked passed, which <see cref="Flush"/> tells with it.
    /// </summary>
    /// <returns>The page whose end goes to the viewers now, <see langword="null"/> for none.</returns>
    public string? Passed()
    {
        if (_shown is null)
        {
            return null;
        }

        _shown = null;
        string id = PageId();
        if (_kept is { } kept && kept.Id == id)
        {
            _kept = kept with { Passed = true };
            return null;
        }

        if (_toldPage != id)
        {
            return null;
        }

        _toldPage = null;
        return id;
    }

    /// <summary>
    /// Tells the page kept while the player skipped once <see cref="SkipSendFrames"/> passed since
    /// the last page told, the skip is let go, the telling ended or another scene was called.
    /// </summary>
    /// <param name="skipHeld">Whether the player holds the game's skip.</param>
    /// <param name="telling">Whether the player tells the story.</param>
    /// <param name="onMap">Whether the map's scene shows.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>The page that goes out now, <see langword="null"/> for none.</returns>
    public PageTold? Flush(bool skipHeld, bool telling, bool onMap, long frame)
    {
        if (_kept is not { } kept || (skipHeld && telling && onMap && _toldAt is { } told && !Past(told, SkipSendFrames, frame)))
        {
            return null;
        }

        _kept = null;
        int skipped = Tell(kept.Id, frame);
        if (kept.Passed)
        {
            _toldPage = null;
        }

        return kept with { Skipped = skipped };
    }

    /// <summary>
    /// Takes that a new telling of the player starts: unless a page is kept, the pace of the skip
    /// and the end to tell start anew.
    /// </summary>
    public void TellingStarts()
    {
        if (_kept is null)
        {
            _toldAt = null;
            _toldPage = null;
        }
    }

    /// <summary>
    /// Keeps a page of another player's story to show once the player is free, its choices written
    /// as one more line; the oldest go past <see cref="MaxHeard"/>.
    /// </summary>
    /// <param name="id">The page's id.</param>
    /// <param name="teller">The teller's name, which the line of the choices names.</param>
    /// <param name="page">The page.</param>
    /// <returns>The pages dropped to stay within <see cref="MaxHeard"/>; -1 for a page without text, which is not kept.</returns>
    public int Hear(string id, string teller, StoryPage page)
    {
        ArgumentNullException.ThrowIfNull(id);
        ArgumentNullException.ThrowIfNull(teller);
        ArgumentNullException.ThrowIfNull(page);
        List<string> lines = [.. page.Lines];
        if (page.Choices.Count > 0)
        {
            lines.Add($"{teller} chooses: {string.Join(" / ", page.Choices)}");
        }

        if (lines.Count == 0)
        {
            return -1;
        }

        _heard.Add(new HeardPage(id, page.Face, page.Index, page.Background, page.Position, lines));
        int dropped = 0;
        while (_heard.Count > MaxHeard)
        {
            _heard.RemoveAt(0);
            dropped++;
        }

        return dropped;
    }

    /// <summary>
    /// Takes that the teller moved past a page of their story; the oldest go past <see cref="MaxDone"/>.
    /// </summary>
    /// <param name="id">The page's id.</param>
    public void Done(string id)
    {
        ArgumentNullException.ThrowIfNull(id);
        _done.Add(id);
        while (_done.Count > MaxDone)
        {
            _done.RemoveAt(0);
        }
    }

    /// <summary>
    /// Forgets the pages heard and those the teller moved past, as another player tells now.
    /// </summary>
    /// <returns>How many pages waited.</returns>
    public int Forget()
    {
        int waiting = _heard.Count;
        _heard.Clear();
        _done.Clear();
        return waiting;
    }

    /// <summary>
    /// Shows the next page heard once the player is free. While something waits for the player to
    /// be free no page starts, and those the teller moved past are left out; once the player shares
    /// no story the pages go; else the oldest the teller moved past are left out while more than
    /// <see cref="CatchUpPages"/> wait.
    /// </summary>
    /// <param name="givingWay">What waits for the player to be free, <see langword="null"/> for nothing.</param>
    /// <param name="sharing">Whether the player shares the story with others.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>What happened, <see langword="null"/> while no page waits.</returns>
    public PagesNext? Next(string? givingWay, bool sharing, long frame)
    {
        if (_heard.Count == 0)
        {
            return null;
        }

        if (givingWay is not null)
        {
            var passed = _heard.Where(page => _done.Contains(page.Id)).Select(page => page.Id).ToList();
            _heard.RemoveAll(page => passed.Contains(page.Id));
            return new PagesNext(null, [], passed, 0);
        }

        if (!sharing)
        {
            int dropped = _heard.Count;
            _heard.Clear();
            return new PagesNext(null, [], [], dropped);
        }

        var skipped = new List<string>();
        while (_heard.Count > CatchUpPages && _done.Contains(_heard[0].Id))
        {
            skipped.Add(_heard[0].Id);
            _heard.RemoveAt(0);
        }

        if (_heard.Count == 0)
        {
            return new PagesNext(null, skipped, [], 0);
        }

        HeardPage page = _heard[0];
        _heard.RemoveAt(0);
        _mirrored = (page.Id, frame, ReadingFrames(page.Lines), false);
        return new PagesNext(page, skipped, [], 0);
    }

    /// <summary>
    /// Tells whether the page the viewer's window holds is over: the teller moved past it and the
    /// player had the time to read it, read on or skips; something waits for the player; more than
    /// <see cref="CatchUpPages"/> pages wait behind it; the teller is no longer the player's; the
    /// relay ended their telling; or a Classic leader's state stopped saying they tell the story
    /// <see cref="StaleFrames"/> ago.
    /// </summary>
    /// <param name="teller">The teller's name, <see langword="null"/> once they are no longer the player's teller or gone.</param>
    /// <param name="telling">Whether the teller tells the story.</param>
    /// <param name="raid">Whether the world is a Raid World, whose telling ends with the relay's word.</param>
    /// <param name="givingWay">What waits for the player to be free, <see langword="null"/> for nothing.</param>
    /// <param name="confirm">Whether the player pressed confirm.</param>
    /// <param name="skip">Whether the player holds the game's skip.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>Whether it is over, with the reason the first time.</returns>
    public PageOver Over(string? teller, bool telling, bool raid, string? givingWay, bool confirm, bool skip, long frame)
    {
        if (_mirrored is not { } mirrored)
        {
            return new PageOver(true, null);
        }

        if (_done.Contains(mirrored.Id))
        {
            string? reason = givingWay is not null ? $"{givingWay} waits for the player"
                : _heard.Count > CatchUpPages ? $"{_heard.Count} more pages wait"
                : Past(mirrored.Since, mirrored.Read, frame) ? "the player read it"
                : confirm ? "the player read on"
                : skip ? "the player skips"
                : null;
            return reason is null ? new PageOver(false, null) : OverFor($"the leader moved past it and {reason}");
        }

        if (teller is null)
        {
            return OverFor("the teller is no longer the player's leader");
        }

        if (telling)
        {
            return new PageOver(false, null);
        }

        if (raid)
        {
            return OverFor("the relay ended the teller's telling");
        }

        return Past(mirrored.Since, StaleFrames, frame) ? OverFor($"the leader stopped telling the story {StaleFrames} frames ago") : new PageOver(false, null);
    }

    /// <summary>
    /// Takes that the viewer's window finished the page it held, or that an event cut it short.
    /// </summary>
    /// <returns>The page it held, <see langword="null"/> for none.</returns>
    public string? Ended()
    {
        string? id = _mirrored?.Id;
        _mirrored = null;
        return id;
    }

    /// <summary>
    /// Tells how long a page stays at least once the teller moved past it.
    /// </summary>
    /// <param name="lines">The page's lines.</param>
    /// <returns>The frames: <see cref="ReadFrames"/> and <see cref="ReadFramesPerCharacter"/> per character, at most <see cref="MostReadFrames"/>.</returns>
    public static int ReadingFrames(IReadOnlyList<string> lines)
    {
        ArgumentNullException.ThrowIfNull(lines);
        long characters = lines.Sum(line => (long)line.EnumerateRunes().Count());
        return (int)Math.Min(ReadFrames + (characters * ReadFramesPerCharacter), MostReadFrames);
    }

    /// <summary>
    /// Reports whether some frames passed since a frame; a frame ahead of now counts as long past.
    /// </summary>
    /// <param name="since">The frame.</param>
    /// <param name="frames">The frames.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>Whether they did.</returns>
    private static bool Past(long since, long frames, long frame)
    {
        long elapsed = frame - since;
        return elapsed < 0 || elapsed >= frames;
    }

    /// <summary>
    /// Reports whether two pages show the same lines and choices.
    /// </summary>
    /// <param name="one">One page.</param>
    /// <param name="other">The other.</param>
    /// <returns>Whether they do.</returns>
    private static bool Same(StoryPage one, StoryPage other) => one.Lines.SequenceEqual(other.Lines) && one.Choices.SequenceEqual(other.Choices);

    /// <summary>
    /// Names the page the teller's story shows now, unique beyond this session, so a viewer's game
    /// never takes a page of an earlier session for one already done.
    /// </summary>
    /// <returns>The id.</returns>
    private string PageId()
    {
        _session ??= _newSession();
        return $"{_session}.{_page}";
    }

    /// <summary>
    /// Notes a page told now.
    /// </summary>
    /// <param name="id">The page's id.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>The pages kept and replaced since the last page told.</returns>
    private int Tell(string id, long frame)
    {
        int skipped = _skipped;
        _skipped = 0;
        _toldAt = frame;
        _toldPage = id;
        return skipped;
    }

    /// <summary>
    /// Reports the page held over, the reason only the first time.
    /// </summary>
    /// <param name="reason">Why.</param>
    /// <returns>The answer.</returns>
    private PageOver OverFor(string reason)
    {
        if (_mirrored is not { } mirrored || mirrored.Over)
        {
            return new PageOver(true, null);
        }

        _mirrored = mirrored with { Over = true };
        return new PageOver(true, reason);
    }
}
