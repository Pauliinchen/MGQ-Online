//----------------------------------------------------------------
//  UiHost.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Ui;

/// <summary>
/// The models of the scripts' interface on one bridge context: the frame's tick hands each model
/// the input its owner put, and the models post what changed as events, which the frame's drain
/// carries back.
/// </summary>
/// <remarks>
/// The scripts stage at most one tick a frame, and none in a frame where no model needs input, so
/// a quiet frame costs nothing.
/// </remarks>
public sealed class UiHost
{
    /// <summary>
    /// The topic of the frame's tick: a Hash of each model's name and its input.
    /// </summary>
    public const string TickTopic = "ui.tick";

    /// <summary>
    /// The models by their names.
    /// </summary>
    private readonly Dictionary<string, IUiModel> _models = new(StringComparer.Ordinal);

    /// <summary>
    /// Creates the host and registers the tick on a context.
    /// </summary>
    /// <param name="context">The context the scripts opened.</param>
    public UiHost(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        Context = context;
        context.Register(TickTopic, (_, request) =>
        {
            Tick(request);
            return null;
        });
    }

    /// <summary>
    /// Gets the context the models post their events on.
    /// </summary>
    public BridgeContext Context { get; }

    /// <summary>
    /// Gets the frame of the last drain, which the models time by.
    /// </summary>
    public long Now => Context.Frame;

    /// <summary>
    /// Adds a model, which takes the input put under its name.
    /// </summary>
    /// <param name="model">The model.</param>
    /// <exception cref="ArgumentException">A model of that name was added already.</exception>
    public void Add(IUiModel model)
    {
        ArgumentNullException.ThrowIfNull(model);
        if (!_models.TryAdd(model.Name, model))
        {
            throw new ArgumentException($"A ui model named {model.Name} was added already.", nameof(model));
        }
    }

    /// <summary>
    /// Posts a model's event.
    /// </summary>
    /// <param name="topic">The event's topic, such as "ui.layout".</param>
    /// <param name="payload">What changed.</param>
    public void Post(string topic, RubyValue payload) => Context.Events.Post(topic, payload);

    /// <summary>
    /// Hands each model of a tick its input, in the order the scripts put them.
    /// </summary>
    /// <remarks>
    /// Every name is checked before the first model runs, so a tick naming a model this build lacks
    /// moves none of them.
    /// </remarks>
    /// <param name="request">The tick.</param>
    /// <exception cref="BridgeRequestException">The tick names a model that was never added.</exception>
    public void Tick(RubyValue request)
    {
        RubyHash inputs = request.AsHash();
        var ready = new List<(IUiModel Model, RubyValue Input)>(inputs.Count);
        foreach ((RubyValue name, RubyValue input) in inputs)
        {
            string text = name.AsText();
            ready.Add(_models.TryGetValue(text, out IUiModel? model) ? (model, input) : throw new BridgeRequestException($"No ui model is named {text}."));
        }

        foreach ((IUiModel model, RubyValue input) in ready)
        {
            model.Tick(input);
        }
    }
}
