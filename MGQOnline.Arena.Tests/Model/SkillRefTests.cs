//----------------------------------------------------------------
//  SkillRefTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Text.Json;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Model;

/// <summary>
/// Tests the skill reference, its key form and its JSON form.
/// </summary>
public sealed class SkillRefTests
{
    /// <summary>
    /// A game skill's key and JSON.
    /// </summary>
    [Fact]
    public void GameSkillHasItsKeyAndJson()
    {
        SkillRef skill = SkillRef.OfGame(1515);

        Assert.Equal("game:1515", skill.Key);
        Assert.Equal("""{"game":1515}""", JsonSerializer.Serialize(skill, ArenaJsonContext.Default.SkillRef));
        Assert.Equal(skill, SkillRef.Parse("game:1515"));
    }

    /// <summary>
    /// A custom skill's key and JSON.
    /// </summary>
    [Fact]
    public void CustomSkillHasItsKeyAndJson()
    {
        SkillRef skill = SkillRef.OfCustom(Samples.BlastId);

        Assert.Equal("custom:" + Samples.BlastId, skill.Key);
        Assert.Equal($$"""{"custom":"{{Samples.BlastId}}"}""", JsonSerializer.Serialize(skill, ArenaJsonContext.Default.SkillRef));
        Assert.Equal(skill, SkillRef.Parse(skill.Key));
    }

    /// <summary>
    /// Keys that name no skill are refused.
    /// </summary>
    /// <param name="key">The key.</param>
    [Theory]
    [InlineData("")]
    [InlineData("1515")]
    [InlineData("game:")]
    [InlineData("game:0")]
    [InlineData("game:01")]
    [InlineData("game:-1")]
    [InlineData("game:1234567890")]
    [InlineData("game: 1")]
    [InlineData("Game:1")]
    [InlineData("custom:Blast")]
    [InlineData("custom:9F3C0A1B2C3D4E5F60718293A4B5C6D7")]
    [InlineData("custom:9f3c0a1b2c3d4e5f60718293a4b5c6d")]
    public void BadKeysAreRefused(string key)
    {
        Assert.False(SkillRef.TryParse(key, out _));
        Assert.Throws<FormatException>(() => SkillRef.Parse(key));
    }

    /// <summary>
    /// JSON that names no skill or more than one is refused.
    /// </summary>
    /// <param name="json">The JSON.</param>
    [Theory]
    [InlineData("""{}""")]
    [InlineData("""{"game":0}""")]
    [InlineData("""{"game":"12"}""")]
    [InlineData("""{"game":1.5}""")]
    [InlineData("""{"custom":"Blast"}""")]
    [InlineData("""{"game":1,"custom":"9f3c0a1b2c3d4e5f60718293a4b5c6d7"}""")]
    [InlineData("""{"skill":1}""")]
    [InlineData("""[1]""")]
    [InlineData("""1""")]
    public void BadJsonIsRefused(string json) =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize(json, ArenaJsonContext.Default.SkillRef));

    /// <summary>
    /// The default value names no skill and cannot be written.
    /// </summary>
    [Fact]
    public void DefaultNamesNoSkill()
    {
        SkillRef none = default;

        Assert.False(none.IsValid);
        Assert.Throws<InvalidOperationException>(() => none.Key);
        Assert.Throws<JsonException>(() => JsonSerializer.Serialize(none, ArenaJsonContext.Default.SkillRef));
    }

    /// <summary>
    /// The factories refuse bad ids.
    /// </summary>
    [Fact]
    public void FactoriesRefuseBadIds()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => SkillRef.OfGame(0));
        Assert.Throws<ArgumentException>(() => SkillRef.OfCustom("Blast"));
    }
}
