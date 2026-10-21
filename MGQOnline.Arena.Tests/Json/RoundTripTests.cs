//----------------------------------------------------------------
//  RoundTripTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Gave the formula refusals a tree and refused a formula without one
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Json;

/// <summary>
/// Tests that every runtime model and event type survives a trip through <see cref="ArenaJsonContext"/>.
/// </summary>
public sealed class RoundTripTests
{
    /// <summary>
    /// The namespaces whose types the JSON contract covers.
    /// </summary>
    private static readonly string[] ContractNamespaces = ["MGQOnline.Arena.Model", "MGQOnline.Arena.Events"];

    /// <summary>
    /// Gets the indexes of every sample, for the theories.
    /// </summary>
    public static TheoryData<int> SampleIndexes => [.. Enumerable.Range(0, Samples.All.Count)];

    /// <summary>
    /// Every concrete type of the model and the events has a sample.
    /// </summary>
    [Fact]
    public void EveryContractTypeHasASample()
    {
        HashSet<Type> sampled = Samples.All.Select(sample => sample.GetType()).ToHashSet();

        string[] missing = ContractTypes()
            .Where(type => !type.IsAbstract && !type.IsEnum && !sampled.Contains(type))
            .Select(type => type.Name)
            .ToArray();

        Assert.Empty(missing);
    }

    /// <summary>
    /// Every contract type, enums and abstract bases included, has a generated contract.
    /// </summary>
    [Fact]
    public void EveryContractTypeIsGenerated()
    {
        string[] missing = ContractTypes()
            .Where(type => ArenaJsonContext.Default.GetTypeInfo(type) is null)
            .Select(type => type.Name)
            .ToArray();

        Assert.Empty(missing);
    }

    /// <summary>
    /// A sample written, read back and written again gives the same bytes and the same type.
    /// </summary>
    /// <param name="index">The sample's index.</param>
    [Theory]
    [MemberData(nameof(SampleIndexes))]
    public void SampleRoundTrips(int index)
    {
        object sample = Samples.All[index];
        JsonTypeInfo typeInfo = ArenaJsonContext.Default.GetTypeInfo(ContractTypeOf(sample.GetType()))!;

        byte[] first = JsonSerializer.SerializeToUtf8Bytes(sample, typeInfo);
        object? read = JsonSerializer.Deserialize(first, typeInfo);
        byte[] second = JsonSerializer.SerializeToUtf8Bytes(read, typeInfo);

        Assert.NotNull(read);
        Assert.Equal(sample.GetType(), read.GetType());
        Assert.Equal(Encoding.UTF8.GetString(first), Encoding.UTF8.GetString(second));
    }

    /// <summary>
    /// Records without collections compare equal after the trip.
    /// </summary>
    [Fact]
    public void FlatRecordsStayEqual()
    {
        object[] flat = Samples.All.Where(sample => !HoldsCollections(sample.GetType())).ToArray();

        foreach (object sample in flat)
        {
            JsonTypeInfo typeInfo = ArenaJsonContext.Default.GetTypeInfo(ContractTypeOf(sample.GetType()))!;
            object? read = JsonSerializer.Deserialize(JsonSerializer.SerializeToUtf8Bytes(sample, typeInfo), typeInfo);
            Assert.Equal(sample, read);
        }

        Assert.NotEmpty(flat);
    }

    /// <summary>
    /// Every enum value is written as its lowerCamel name and read back.
    /// </summary>
    [Fact]
    public void EnumsAreLowerCamelStrings()
    {
        foreach (Type type in ContractTypes().Where(type => type.IsEnum))
        {
            JsonTypeInfo typeInfo = ArenaJsonContext.Default.GetTypeInfo(type)!;
            foreach (object value in Enum.GetValues(type))
            {
                string name = value.ToString()!;
                string json = JsonSerializer.Serialize(value, typeInfo);

                Assert.Equal($"\"{char.ToLowerInvariant(name[0])}{name[1..]}\"", json);
                Assert.Equal(value, JsonSerializer.Deserialize(json, typeInfo));
            }
        }
    }

    /// <summary>
    /// An enum given as a number is refused.
    /// </summary>
    [Fact]
    public void EnumNumbersAreRefused() =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("1", ArenaJsonContext.Default.SkillKind));

    /// <summary>
    /// A member the contract does not know is refused.
    /// </summary>
    [Fact]
    public void UnknownMembersAreRefused() =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("""{"ast":{"type":"number","text":"1"},"text":"1","extra":2}""", ArenaJsonContext.Default.FormulaSpec));

    /// <summary>
    /// An explicit null for a member that is never null is refused.
    /// </summary>
    [Fact]
    public void NullForANonNullableMemberIsRefused() =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("""{"ast":{"type":"number","text":"1"},"text":null}""", ArenaJsonContext.Default.FormulaSpec));

    /// <summary>
    /// A missing member that is never null is refused.
    /// </summary>
    [Fact]
    public void MissingNonNullableMembersAreRefused()
    {
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("{}", ArenaJsonContext.Default.FormulaSpec));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("""{"text":"1"}""", ArenaJsonContext.Default.FormulaSpec));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("""{"pool":"hp"}""", ArenaJsonContext.Default.RestorationSpec));
    }

    /// <summary>
    /// A missing member that may be null reads as null.
    /// </summary>
    [Fact]
    public void MissingNullableMembersReadAsNull()
    {
        TargetSpec target = JsonSerializer.Deserialize("""{"mode":"mostHit","newTargetEachPulse":true}""", ArenaJsonContext.Default.TargetSpec)!;

        Assert.Equal(new TargetSpec(TargetMode.MostHit, true), target);
    }

    /// <summary>
    /// A polymorphic object is read whatever place its type has, as canonical JSON sorts it among the keys.
    /// </summary>
    [Fact]
    public void TypeMayComeLast()
    {
        TriggerSpec? trigger = JsonSerializer.Deserialize("""{"a":2,"b":3,"type":"turnSchedule"}""", ArenaJsonContext.Default.TriggerSpec);

        Assert.Equal(new TurnScheduleTrigger(2, 3), trigger);
    }

    /// <summary>
    /// A polymorphic object of an unknown type is refused.
    /// </summary>
    [Fact]
    public void UnknownTypesAreRefused() =>
        Assert.ThrowsAny<JsonException>(() => JsonSerializer.Deserialize("""{"type":"castNow"}""", ArenaJsonContext.Default.EffectSpec));

    /// <summary>
    /// The value types use their compact array forms.
    /// </summary>
    [Fact]
    public void ValueTypesUseArrays()
    {
        Assert.Equal("[3,4]", JsonSerializer.Serialize(new GridCell(3, 4), ArenaJsonContext.Default.GridCell));
        Assert.Equal("[16,10]", JsonSerializer.Serialize(new GridSize(16, 10), ArenaJsonContext.Default.GridSize));
        Assert.Equal("[255,120,40,160]", JsonSerializer.Serialize(new ColorRgba(255, 120, 40, 160), ArenaJsonContext.Default.ColorRgba));
        Assert.Equal("[\"Dungeon_A2\",1536]", JsonSerializer.Serialize(new TileRef("Dungeon_A2", 1536), ArenaJsonContext.Default.TileRef));
        Assert.Equal("[4181,7]", JsonSerializer.Serialize(new PowerSize(4181, 7), ArenaJsonContext.Default.PowerSize));
    }

    /// <summary>
    /// Malformed value types are refused.
    /// </summary>
    /// <param name="json">The JSON of a colour.</param>
    [Theory]
    [InlineData("[1,2,3]")]
    [InlineData("[1,2,3,4,5]")]
    [InlineData("[1,2,3,256]")]
    [InlineData("[1,2,3,-1]")]
    [InlineData("[1,2,3,4.5]")]
    [InlineData("{\"r\":1}")]
    public void MalformedColoursAreRefused(string json) =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize(json, ArenaJsonContext.Default.ColorRgba));

    /// <summary>
    /// A grid without columns or rows is refused.
    /// </summary>
    [Fact]
    public void EmptyGridsAreRefused() =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize("[0,6]", ArenaJsonContext.Default.GridSize));

    /// <summary>
    /// A dictionary keyed by integers writes its keys as strings and reads them back.
    /// </summary>
    [Fact]
    public void IntegerKeysRoundTrip()
    {
        string json = JsonSerializer.Serialize(Samples.Tier, ArenaJsonContext.Default.RuntimeTier);
        RuntimeTier read = JsonSerializer.Deserialize(json, ArenaJsonContext.Default.RuntimeTier)!;

        Assert.Contains("\"elementRates\":{\"3\":50,\"1\":125.5}", json, StringComparison.Ordinal);
        Assert.Equal(125.5, read.ElementRates[1]);
    }

    /// <summary>
    /// Gets every public type of the contract namespaces.
    /// </summary>
    /// <returns>The types.</returns>
    private static IEnumerable<Type> ContractTypes() =>
        typeof(RuntimeDesign).Assembly.GetExportedTypes()
            .Where(type => ContractNamespaces.Contains(type.Namespace) && !type.IsInterface && !type.IsGenericTypeDefinition);

    /// <summary>
    /// Gets the type whose contract writes a value: its polymorphic base, else itself.
    /// </summary>
    /// <param name="type">The value's type.</param>
    /// <returns>The contract type.</returns>
    private static Type ContractTypeOf(Type type)
    {
        for (Type? candidate = type; candidate is not null; candidate = candidate.BaseType)
        {
            if (candidate.GetCustomAttribute<JsonPolymorphicAttribute>() is not null)
            {
                return candidate;
            }
        }

        return type;
    }

    /// <summary>
    /// Tells whether a type has a collection member, which records compare by reference.
    /// </summary>
    /// <param name="type">The type.</param>
    /// <returns>Whether any public property is a collection.</returns>
    private static bool HoldsCollections(Type type) =>
        type.GetProperties(BindingFlags.Public | BindingFlags.Instance).Any(property => property.PropertyType != typeof(string) && typeof(System.Collections.IEnumerable).IsAssignableFrom(property.PropertyType))
        || type.GetProperties(BindingFlags.Public | BindingFlags.Instance).Any(property => !property.PropertyType.IsPrimitive && property.PropertyType.Namespace == "MGQOnline.Arena.Model"
            && property.PropertyType.IsClass && HoldsCollections(property.PropertyType));
}
