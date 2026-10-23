//----------------------------------------------------------------
//  IUiModel.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Ui;

/// <summary>
/// A model of the scripts' interface that follows the frame's input, such as the layout or a
/// wheel: its owner in the scripts puts the model's input into the frame's tick, and the model
/// posts what changed as an event of its own.
/// </summary>
public interface IUiModel
{
    /// <summary>
    /// Gets the name the model's input goes under in the tick, such as "layout".
    /// </summary>
    string Name { get; }

    /// <summary>
    /// Follows the input the scripts put for the model in a frame.
    /// </summary>
    /// <param name="input">The input, as the model's owner wrote it.</param>
    void Tick(RubyValue input);
}
