//----------------------------------------------------------------
//  UiTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Game.Ui.Layout;
using MGQOnline.Game.Ui.Text;
using MGQOnline.Game.Ui.Wheels;

namespace MGQOnline.Game.Ui;

/// <summary>
/// Puts the interface's models and topics on a context, as a host's setup does for each handshake.
/// </summary>
public static class UiTopics
{
    /// <summary>
    /// Registers the tick and every model of the interface on a context.
    /// </summary>
    /// <param name="context">The context the scripts opened.</param>
    /// <param name="keyboard">What the player types, null where nobody types, which leaves the text box out.</param>
    /// <returns>The host that holds the models.</returns>
    public static UiHost Register(BridgeContext context, ITypedText? keyboard = null)
    {
        ArgumentNullException.ThrowIfNull(context);
        var host = new UiHost(context);
        var text = new UiText(host);
        if (keyboard is not null)
        {
            host.Add(new EditModel(host, text, keyboard));
        }

        var actions = new WheelModel(host, "wheel", hasCenter: true, closesOnConfirm: false);
        var emotes = new WheelModel(host, "emotes", hasCenter: false, closesOnConfirm: true);
        host.Add(actions);
        host.Add(emotes);
        WheelModel.RegisterTopics(context, actions, emotes);
        host.Add(new ConfirmModel(host));
        host.Add(new LayoutModel(host));
        return host;
    }
}
