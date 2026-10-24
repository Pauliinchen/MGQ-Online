//----------------------------------------------------------------
//  SiteFeedTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Text;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers reading the website's list of mods, which counts only with the website's signature.
/// </summary>
public sealed class SiteFeedTests
{
    /// <summary>
    /// A list of one mod in two versions, the older one listed first.
    /// </summary>
    private static readonly byte[] Feed = Encoding.UTF8.GetBytes("""
        {"schema":1,"generatedAt":"2026-10-24T08:00:00+00:00","mods":[{"slug":"character-pack","name":"Character Pack","summary":"Adds characters.","description":null,"author":"Someone","downloads":3,"page":"https://mgqonline.org/mods/character-pack",
         "versions":[
          {"version":"1.0","changelog":"First.","uploadedAt":"2026-10-20T10:00:00+00:00","scannedAt":null,"package":{"name":"Pack.zip","size":10,"sha256":"AA","url":"https://mgqonline.org/mods/character-pack/1.0/download"},"files":[{"path":"Patch/Pack.rb","size":1,"sha256":"BB"}]},
          {"version":"1.1","changelog":"Second.","uploadedAt":"2026-10-22T10:00:00+00:00","scannedAt":null,"package":{"name":"Pack.zip","size":12,"sha256":"cc","url":"https://mgqonline.org/mods/character-pack/1.1/download"},"files":[{"path":"Patch/Pack.rb","size":1,"sha256":"dd"},{"path":"Patch/Pack/a.png","size":1,"sha256":"ee"}]}]}]}
        """);

    /// <summary>
    /// Asserts that a list signed with the key is read, its latest upload first.
    /// </summary>
    [Fact]
    public void Fetch_SignedList_IsRead()
    {
        var website = new FakeWebsite { [SiteFeed.Address] = () => FakeWebsite.Signed(Feed) };

        var mod = Assert.Single(SiteFeed.Fetch(TestKey.Key, website.Client()));

        Assert.Equal(("character-pack", "Character Pack", "Someone"), (mod.Slug, mod.Name, mod.Author));
        Assert.Equal(["1.1", "1.0"], mod.Versions.Select(version => version.Version));
        Assert.Equal(new SitePackage("Pack.zip", 12, "cc", "https://mgqonline.org/mods/character-pack/1.1/download"), mod.Versions[0].Package);
        Assert.Equal("dd", mod.Versions[0].Files["Patch/Pack.rb"]);
    }

    /// <summary>
    /// Asserts that a list without a signature, of another key or with a wrong signature is refused as unverified.
    /// </summary>
    [Fact]
    public void Fetch_ListNotSignedWithTheKey_IsRefused()
    {
        var unsigned = new FakeWebsite { [SiteFeed.Address] = () => new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(Feed) } };
        var foreign = new FakeWebsite { [SiteFeed.Address] = () => FakeWebsite.Signed(Feed, keyId: "0123456789abcdef") };
        var changed = new FakeWebsite { [SiteFeed.Address] = () => FakeWebsite.Signed(Feed, body: [.. Feed, (byte)' ']) };

        foreach (var website in new[] { unsigned, foreign, changed })
        {
            Assert.Equal(SiteFeed.Unverified, Assert.Throws<SiteFeedException>(() => SiteFeed.Fetch(TestKey.Key, website.Client())).Message);
        }
    }

    /// <summary>
    /// Asserts that a website answering with an error counts as not reached.
    /// </summary>
    [Fact]
    public void Fetch_Error_IsUnreachable()
    {
        var website = new FakeWebsite();

        Assert.Equal(SiteFeed.Unreachable, Assert.Throws<SiteFeedException>(() => SiteFeed.Fetch(TestKey.Key, website.Client())).Message);
    }
}

/// <summary>
/// A key pair of the tests' own, which signs lists as the website does.
/// </summary>
internal static class TestKey
{
    /// <summary>
    /// The private key.
    /// </summary>
    private static readonly ECDsa Signer = ECDsa.Create(ECCurve.NamedCurves.nistP256);

    /// <summary>
    /// The public key, as the DLL pins the website's.
    /// </summary>
    public static FeedKey Key { get; } = KeyOf(Signer);

    /// <summary>
    /// Signs a list as the website does.
    /// </summary>
    /// <param name="body">The list.</param>
    /// <returns>The signature header's value.</returns>
    public static string Sign(byte[] body) =>
        Convert.ToBase64String(Signer.SignData(body, HashAlgorithmName.SHA256, DSASignatureFormat.IeeeP1363FixedFieldConcatenation));

    /// <summary>
    /// Writes a key's public part as a JWK names it.
    /// </summary>
    /// <param name="signer">The key.</param>
    /// <returns>The public key.</returns>
    private static FeedKey KeyOf(ECDsa signer)
    {
        var point = signer.ExportParameters(includePrivateParameters: false).Q;
        return new FeedKey("test-key", Base64Url.EncodeToString(point.X), Base64Url.EncodeToString(point.Y));
    }
}

/// <summary>
/// The website inside the test: an answer made for each address, and the addresses asked for.
/// </summary>
internal sealed class FakeWebsite : HttpMessageHandler
{
    /// <summary>
    /// What makes the answer to each address, by address.
    /// </summary>
    private readonly Dictionary<string, Func<HttpResponseMessage>> _answers = new(StringComparer.Ordinal);

    /// <summary>
    /// The addresses asked for, in order.
    /// </summary>
    public List<string> Requested { get; } = [];

    /// <summary>
    /// What makes the answer to an address.
    /// </summary>
    /// <param name="url">The address.</param>
    /// <returns>What makes the answer.</returns>
    public Func<HttpResponseMessage> this[string url]
    {
        get => _answers[url];
        set => _answers[url] = value;
    }

    /// <summary>
    /// Makes an answer that carries a list signed with the tests' key.
    /// </summary>
    /// <param name="signed">The list signed.</param>
    /// <param name="keyId">The key id named; <see langword="null"/> for the tests' key.</param>
    /// <param name="body">The list sent; <see langword="null"/> for the one signed.</param>
    /// <returns>The answer.</returns>
    public static HttpResponseMessage Signed(byte[] signed, string? keyId = null, byte[]? body = null)
    {
        var response = new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(body ?? signed) };
        response.Headers.Add(SiteFeed.SignatureHeader, TestKey.Sign(signed));
        response.Headers.Add(SiteFeed.KeyHeader, keyId ?? TestKey.Key.Id);
        return response;
    }

    /// <summary>
    /// Makes a client that asks this website.
    /// </summary>
    /// <returns>The client.</returns>
    public HttpClient Client() => new(this);

    /// <inheritdoc />
    protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var url = request.RequestUri!.ToString();
        Requested.Add(url);
        return _answers.TryGetValue(url, out var answer) ? answer() : new HttpResponseMessage(HttpStatusCode.NotFound);
    }

    /// <inheritdoc />
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
        Task.FromResult(Send(request, cancellationToken));
}
