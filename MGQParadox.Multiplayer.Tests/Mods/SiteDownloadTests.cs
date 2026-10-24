//----------------------------------------------------------------
//  SiteDownloadTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers the rules a download of the website's mods follows: only the website, and only the file the list names.
/// </summary>
public sealed class SiteDownloadTests
{
    /// <summary>
    /// A package's address as the list names it.
    /// </summary>
    private const string PackageUrl = "https://mgqonline.org/mods/level-cap/1.5.2/download";

    /// <summary>
    /// Where the website stores the package.
    /// </summary>
    private const string StoredUrl = "https://mgqonline.org/files/level-cap-1.5.2.rb";

    /// <summary>
    /// The package.
    /// </summary>
    private static readonly byte[] Package = [1, 2, 3];

    /// <summary>
    /// Asserts that a redirect within the website is followed and the file taken when its hash is the list's.
    /// </summary>
    [Fact]
    public void Get_FollowsARedirectWithinTheWebsite()
    {
        var website = new FakeWebsite { [PackageUrl] = () => Redirect(StoredUrl), [StoredUrl] = () => File(Package) };

        Assert.Equal(Package, SiteDownload.Get(PackageUrl, Sha256Of(Package), website.Client()));
        Assert.Equal([PackageUrl, StoredUrl], website.Requested);
    }

    /// <summary>
    /// Asserts that an address off the website, plain HTTP and a redirect elsewhere are refused before anything is taken from there.
    /// </summary>
    [Fact]
    public void Get_RefusesEverythingOffTheWebsite()
    {
        var website = new FakeWebsite { [PackageUrl] = () => Redirect("https://example.com/level-cap.rb") };

        Assert.Throws<InvalidOperationException>(() => SiteDownload.Get("https://example.com/level-cap.rb", Sha256Of(Package), website.Client()));
        Assert.Throws<InvalidOperationException>(() => SiteDownload.Get("http://mgqonline.org/mods/level-cap/1.5.2/download", Sha256Of(Package), website.Client()));
        Assert.Contains("example.com", Assert.Throws<InvalidOperationException>(() => SiteDownload.Get(PackageUrl, Sha256Of(Package), website.Client())).Message);
        Assert.Equal([PackageUrl], website.Requested);
    }

    /// <summary>
    /// Asserts that a file whose hash is not the list's is refused.
    /// </summary>
    [Fact]
    public void Get_FileThatDiffersFromTheList_IsRefused()
    {
        var website = new FakeWebsite { [PackageUrl] = () => File([9, 9]) };

        Assert.Contains("differs", Assert.Throws<InvalidOperationException>(() => SiteDownload.Get(PackageUrl, Sha256Of(Package), website.Client())).Message);
    }

    /// <summary>
    /// Hashes a file as the website's list does.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The SHA-256 of its raw bytes, lowercase hexadecimal.</returns>
    private static string Sha256Of(byte[] bytes) => Convert.ToHexStringLower(SHA256.HashData(bytes));

    /// <summary>
    /// Makes an answer that sends the download on.
    /// </summary>
    /// <param name="location">Where to.</param>
    /// <returns>The answer.</returns>
    private static HttpResponseMessage Redirect(string location)
    {
        var response = new HttpResponseMessage(HttpStatusCode.Found);
        response.Headers.Location = new Uri(location);
        return response;
    }

    /// <summary>
    /// Makes an answer that carries a file.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The answer.</returns>
    private static HttpResponseMessage File(byte[] bytes) => new(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) };
}
