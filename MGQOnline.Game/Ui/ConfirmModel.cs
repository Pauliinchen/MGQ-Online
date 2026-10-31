//----------------------------------------------------------------
//  ConfirmModel.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Started a box with its yes choice picked when asked
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Ui;

/// <summary>
/// The yes/no box over any scene (MGQ_MpUi::Confirm), one at a time: which choice is picked and
/// what answers it. The scripts keep the box's picture, its scene and the block its answer goes
/// to, and hand the answer over a tick after the one that gave it, once the press ended.
/// </summary>
public sealed class ConfirmModel : IUiModel
{
    /// <summary>
    /// Opens a box, true to start with its yes choice picked in; its id out, nil while one is open.
    /// </summary>
    public const string AskTopic = "ui.confirm.ask";

    /// <summary>
    /// Closes the box of an id without an answer from the player: [id].
    /// </summary>
    public const string CloseTopic = "ui.confirm.close";

    /// <summary>
    /// The box's event: {"id", "picked", "answer" and "by" once answered, "cues"}.
    /// </summary>
    public const string EventTopic = "ui.confirm";

    /// <summary>
    /// The host the box posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The open box's id, null while none is.
    /// </summary>
    private int? _open;

    /// <summary>
    /// The id the last box got.
    /// </summary>
    private int _lastId;

    /// <summary>
    /// Whether the yes choice is picked; the no choice starts picked unless the ask says otherwise.
    /// </summary>
    private bool _picked;

    /// <summary>
    /// Whether the box has not taken a tick yet, which is the tick of the frame it opened in.
    /// </summary>
    private bool _fresh;

    /// <summary>
    /// Creates the box and registers its topics.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    public ConfirmModel(UiHost host)
    {
        ArgumentNullException.ThrowIfNull(host);
        _host = host;
        host.Context.Register(AskTopic, (_, request) =>
        {
            if (_open is not null)
            {
                return RubyNil.Value;
            }

            _open = ++_lastId;
            _picked = request is { IsNil: false } && request.AsBool();
            _fresh = true;
            return _lastId;
        });
        host.Context.Register(CloseTopic, (_, request) =>
        {
            if (_open == request.AsArray()[0].AsInt())
            {
                _open = null;
            }

            return null;
        });
    }

    /// <inheritdoc />
    public string Name => "confirm";

    /// <summary>
    /// Reads a frame's keys: [id, the accept hotkey, the decline hotkey, cancel, confirm, left or
    /// right]. The accept hotkey answers yes, the decline hotkey and cancel no, confirm the choice
    /// picked, left or right move the pick; nothing reads in the tick of the frame the box opened in,
    /// where the press that asked would answer it.
    /// </summary>
    /// <param name="input">The owner's input.</param>
    public void Tick(RubyValue input)
    {
        RubyArray keys = input.AsArray();
        if (_open is not int id || id != keys[0].AsInt())
        {
            return;
        }

        if (_fresh)
        {
            _fresh = false;
            return;
        }

        if (keys[1].AsBool())
        {
            Answer(id, true, "accept");
        }
        else if (keys[2].AsBool())
        {
            Answer(id, false, "decline");
        }
        else if (keys[3].AsBool())
        {
            Answer(id, false, "cancel");
        }
        else if (keys[4].AsBool())
        {
            Answer(id, _picked, "confirm");
        }
        else if (keys[5].AsBool())
        {
            _picked = !_picked;
            _host.Post(EventTopic, new RubyHash { { "id", id }, { "picked", _picked }, { UiCue.Key, new RubyArray { UiCue.Cursor } } });
        }
    }

    /// <summary>
    /// Answers the box and posts the answer with its sound.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="yes">The answer.</param>
    /// <param name="by">What answered: "accept", "decline", "cancel" or "confirm".</param>
    private void Answer(int id, bool yes, string by)
    {
        _open = null;
        _host.Post(EventTopic, new RubyHash { { "id", id }, { "picked", _picked }, { "answer", yes }, { "by", by }, { UiCue.Key, new RubyArray { yes ? UiCue.Ok : UiCue.Cancel } } });
    }
}
