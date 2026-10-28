//----------------------------------------------------------------
//  SceneQueue.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Scene;

/// <summary>
/// A change of the story's scene waiting to go out to those who see it.
/// </summary>
/// <param name="Kind">What changes, such as "picture.show".</param>
/// <param name="Args">Its arguments.</param>
/// <param name="Map">The map it happened on.</param>
/// <param name="Logged">Whether the teller logs it; false for one that goes several times a second.</param>
public sealed record SceneChange(string Kind, IReadOnlyList<WireValue> Args, int Map, bool Logged);

/// <summary>
/// One message of changes of a map, see <see cref="SceneQueue.Flush"/>.
/// </summary>
/// <param name="Map">The map the changes happened on.</param>
/// <param name="Changes">The changes, in their order.</param>
/// <param name="Args">The message's arguments: a lone change's own line, else the line of each
/// change as [kind, args], joined by tabs.</param>
public sealed record SceneMessage(int Map, IReadOnlyList<SceneChange> Changes, string Args)
{
    /// <summary>
    /// Gets what the message names its change: a lone change's kind, which earlier builds take,
    /// else <see cref="SceneQueue.BatchKind"/>.
    /// </summary>
    public string Kind => Changes.Count == 1 ? Changes[0].Kind : SceneQueue.BatchKind;
}

/// <summary>
/// The teller's changes of the story's scene waiting to go out, as coop_scene.rbx kept them: merged
/// as they come (<see cref="Add"/>) and split into the messages they go out in (<see cref="Flush"/>).
/// </summary>
public sealed class SceneQueue
{
    /// <summary>
    /// What a message holding several changes names its change; earlier builds ignore it as an
    /// unknown change.
    /// </summary>
    public const string BatchKind = "batch";

    /// <summary>
    /// Most changes one message holds; a viewer drops a message with more.
    /// </summary>
    public const int MaxBatch = 256;

    /// <summary>
    /// Most bytes the changes of one message take together, which leaves room for the other fields
    /// below the 262,103 bytes of a world message the DLL sends.
    /// </summary>
    public const int MaxBatchBytes = 240 * 1024;

    /// <summary>
    /// Frames between two messages at most while the player holds the game's skip, which passes a
    /// page every frame, so the sends stay far below the relay's limit per connection.
    /// </summary>
    public const int SkipSendFrames = 10;

    /// <summary>
    /// What the changes of a picture start with.
    /// </summary>
    private const string PictureKinds = "picture.";

    /// <summary>
    /// A picture's move, which replaces its last move that nothing else of the picture followed.
    /// </summary>
    private const string PictureMove = "picture.move";

    /// <summary>
    /// The camera's place, which replaces its last.
    /// </summary>
    private const string Camera = "map.camera";

    /// <summary>
    /// A sound effect, which replaces the last while the player holds the game's skip.
    /// </summary>
    private const string SoundEffect = "audio.se_play";

    /// <summary>
    /// The story's values, which merge with those waiting.
    /// </summary>
    private const string StoryValues = "story.values";

    /// <summary>
    /// The changes waiting, in their order.
    /// </summary>
    private readonly List<SceneChange> _outgoing = [];

    /// <summary>
    /// The frame the last messages went out at, <see langword="null"/> before any.
    /// </summary>
    private long? _flushedAt;

    /// <summary>
    /// Gets how many changes wait.
    /// </summary>
    public int Count => _outgoing.Count;

    /// <summary>
    /// Keeps a change, leaving out the one waiting that it makes needless: the last move of the
    /// same picture unless anything else of that picture came after it, the camera's last place, and
    /// while the player holds the game's skip the last sound effect. The story values waiting merge
    /// into the new ones, the newer value of each key kept, the older values first. A move route is
    /// never left out, since a viewer's character may have walked part of it.
    /// </summary>
    /// <param name="kind">What changes.</param>
    /// <param name="args">Its arguments.</param>
    /// <param name="map">The map it happened on.</param>
    /// <param name="logged">Whether the teller logs it.</param>
    /// <param name="skipHeld">Whether the player holds the game's skip.</param>
    public void Add(string kind, IReadOnlyList<WireValue> args, int map, bool logged, bool skipHeld)
    {
        ArgumentNullException.ThrowIfNull(kind);
        ArgumentNullException.ThrowIfNull(args);
        switch (kind)
        {
            case PictureMove:
                int last = _outgoing.FindLastIndex(entry => entry.Kind.StartsWith(PictureKinds, StringComparison.Ordinal) && SameFirst(entry.Args, args));
                if (last >= 0 && _outgoing[last].Kind == kind)
                {
                    _outgoing.RemoveAt(last);
                }

                break;
            case Camera:
                _outgoing.RemoveAll(entry => entry.Kind == kind);
                break;
            case SoundEffect:
                if (skipHeld)
                {
                    _outgoing.RemoveAll(entry => entry.Kind == kind);
                }

                break;
            case StoryValues:
                int waiting = _outgoing.FindLastIndex(entry => entry.Kind == kind);
                if (waiting >= 0)
                {
                    var keys = args.Select(KeyOf).ToList();
                    IReadOnlyList<WireValue> older = _outgoing[waiting].Args;
                    _outgoing.RemoveAt(waiting);
                    args = [.. older.Where(value => !keys.Contains(KeyOf(value))), .. args];
                }

                break;
        }

        _outgoing.Add(new SceneChange(kind, args, map, logged));
    }

    /// <summary>
    /// Reports whether the changes waiting go out now: every frame, but while the player holds the
    /// game's skip and the story plays on the map only <see cref="SkipSendFrames"/> after the last
    /// went out.
    /// </summary>
    /// <param name="frame">The frame now.</param>
    /// <param name="skipHeld">Whether the player holds the game's skip.</param>
    /// <param name="playing">Whether the story plays on the map screen.</param>
    /// <returns>Whether they do.</returns>
    public bool Due(long frame, bool skipHeld, bool playing) =>
        !skipHeld || !playing || _flushedAt is not { } at || frame - at >= SkipSendFrames || frame < at;

    /// <summary>
    /// Takes the changes waiting as the messages they go out in: in their order, grouped by the map
    /// they happened on, each message within <see cref="MaxBatch"/> changes and
    /// <see cref="MaxBatchBytes"/>; a lone change longer than that goes out alone.
    /// </summary>
    /// <param name="frame">The frame they go out at, which <see cref="Due"/> counts from.</param>
    /// <returns>The messages, none while nothing waits.</returns>
    public IReadOnlyList<SceneMessage> Flush(long frame = 0)
    {
        if (_outgoing.Count > 0)
        {
            _flushedAt = frame;
        }

        var messages = new List<SceneMessage>();
        var group = new List<SceneChange>();
        foreach (SceneChange change in _outgoing)
        {
            if (group.Count > 0 && group[0].Map != change.Map)
            {
                Split(group, messages);
                group = [];
            }

            group.Add(change);
        }

        if (group.Count > 0)
        {
            Split(group, messages);
        }

        _outgoing.Clear();
        return messages;
    }

    /// <summary>
    /// Forgets the changes waiting and when the last went out.
    /// </summary>
    public void Clear()
    {
        _outgoing.Clear();
        _flushedAt = null;
    }

    /// <summary>
    /// Splits the changes of one map into their messages.
    /// </summary>
    /// <param name="group">The changes.</param>
    /// <param name="messages">Where the messages go.</param>
    private static void Split(List<SceneChange> group, List<SceneMessage> messages)
    {
        var batch = new List<(SceneChange Change, string Line)>();
        long bytes = -1;
        foreach (SceneChange change in group)
        {
            string line = WireWriter.Line(new WireList(change.Kind, new WireList(change.Args)));
            int size = Encoding.UTF8.GetByteCount(line);
            if (batch.Count >= MaxBatch || (batch.Count > 0 && bytes + 1 + size > MaxBatchBytes))
            {
                messages.Add(MessageOf(batch));
                batch = [];
                bytes = -1;
            }

            bytes += 1 + size;
            batch.Add((change, line));
        }

        messages.Add(MessageOf(batch));
    }

    /// <summary>
    /// Makes the message of a batch.
    /// </summary>
    /// <param name="batch">The changes with their lines.</param>
    /// <returns>The message.</returns>
    private static SceneMessage MessageOf(List<(SceneChange Change, string Line)> batch)
    {
        string args = batch.Count == 1 ? WireWriter.Line(batch[0].Change.Args) : string.Join('\t', batch.Select(entry => entry.Line));
        return new SceneMessage(batch[0].Change.Map, [.. batch.Select(entry => entry.Change)], args);
    }

    /// <summary>
    /// Reports whether two changes name the same picture, by their first argument.
    /// </summary>
    /// <param name="one">The arguments of one.</param>
    /// <param name="other">The arguments of the other.</param>
    /// <returns>Whether they do; two without a first argument do.</returns>
    private static bool SameFirst(IReadOnlyList<WireValue> one, IReadOnlyList<WireValue> other)
    {
        if (one.Count == 0 || other.Count == 0)
        {
            return one.Count == other.Count;
        }

        return one[0].Equals(other[0]);
    }

    /// <summary>
    /// Finds a story value's key: its kind and key, the first two of [kind, key, value].
    /// </summary>
    /// <param name="value">The story value.</param>
    /// <returns>The key; a value that is no list is its own key.</returns>
    private static WireValue KeyOf(WireValue value) => value is WireList list ? new WireList(list.Items.Take(2).ToList()) : value;
}
