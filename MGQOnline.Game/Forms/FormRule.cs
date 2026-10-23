//----------------------------------------------------------------
//  FormRule.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Forms;

/// <summary>
/// What a form's field asks of the form's values, such as whether it shows or may be used.
/// </summary>
public abstract record FormRule
{
    /// <summary>
    /// Makes a rule that holds while a switch has an outcome picked.
    /// </summary>
    /// <param name="key">The switch's key.</param>
    /// <param name="index">The outcome's index.</param>
    /// <returns>The rule.</returns>
    public static FormRule Choice(string key, int index) => new ChoiceRule(key, index);

    /// <summary>
    /// Makes a rule that holds while a checkbox is ticked.
    /// </summary>
    /// <param name="key">The checkbox's key.</param>
    /// <returns>The rule.</returns>
    public static FormRule Ticked(string key) => new TickedRule(key);

    /// <summary>
    /// Makes a rule that holds while a fact the form was opened with is true.
    /// </summary>
    /// <param name="name">The fact, such as "discord".</param>
    /// <returns>The rule.</returns>
    public static FormRule Fact(string name) => new FactRule(name);

    /// <summary>
    /// Makes a rule that holds while another does not.
    /// </summary>
    /// <param name="rule">The other rule.</param>
    /// <returns>The rule.</returns>
    public static FormRule Not(FormRule rule) => new NotRule(rule);

    /// <summary>
    /// Tells whether the rule holds.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <returns>Whether it holds.</returns>
    public abstract bool Holds(Form form);

    /// <summary>
    /// Holds while a switch has an outcome picked.
    /// </summary>
    /// <param name="Key">The switch's key.</param>
    /// <param name="Index">The outcome's index.</param>
    private sealed record ChoiceRule(string Key, int Index) : FormRule
    {
        /// <inheritdoc />
        public override bool Holds(Form form) => form.ChoiceOf(Key) == Index;
    }

    /// <summary>
    /// Holds while a checkbox is ticked.
    /// </summary>
    /// <param name="Key">The checkbox's key.</param>
    private sealed record TickedRule(string Key) : FormRule
    {
        /// <inheritdoc />
        public override bool Holds(Form form) => form.IsTicked(Key);
    }

    /// <summary>
    /// Holds while a fact the form was opened with is true.
    /// </summary>
    /// <param name="Name">The fact.</param>
    private sealed record FactRule(string Name) : FormRule
    {
        /// <inheritdoc />
        public override bool Holds(Form form) => form.Facts.Contains(Name);
    }

    /// <summary>
    /// Holds while another rule does not.
    /// </summary>
    /// <param name="Rule">The other rule.</param>
    private sealed record NotRule(FormRule Rule) : FormRule
    {
        /// <inheritdoc />
        public override bool Holds(Form form) => !Rule.Holds(form);
    }
}
