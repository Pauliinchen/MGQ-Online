//----------------------------------------------------------------
//  ReleaseDownloadTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers the rules a release download follows redirects by, against a GitHub played by a handler inside the test.
/// </summary>
public sealed class ReleaseDownloadTests
{
    /// <summary>
    /// A release file's address as the catalog names it.
    /// </summary>
    private const string ReleaseUrl = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.4.0/Level_Cap.rb";

    /// <summary>
    /// A file host's address.
    /// </summary>
    private const string FileUrl = "https://objects.githubusercontent.com/file";

    /// <summary>
    /// Asserts that a redirect to a GitHub file host is followed and the file read from there.
    /// </summary>
    [Fact]
    public void Get_FollowsARedirectToAFileHost()
    {
        var github = new FakeGitHub
        {
            [ReleaseUrl] = Redirect(FileUrl),
            [FileUrl] = File([1, 2, 3]),
        };

        Assert.Equal([1, 2, 3], ReleaseDownload.Get(ReleaseUrl, github.Client()));
        Assert.Equal([ReleaseUrl, FileUrl], github.Requested);
    }

    /// <summary>
    /// Asserts that a redirect to any other host, or to nowhere, is refused before it is followed.
    /// </summary>
    [Fact]
    public void Get_RefusesARedirectOffTheFileHosts()
    {
        var elsewhere = new FakeGitHub { [ReleaseUrl] = Redirect("https://example.com/file") };
        var nowhere = new FakeGitHub { [ReleaseUrl] = new HttpResponseMessage(HttpStatusCode.Found) };
        var plain = new FakeGitHub { [ReleaseUrl] = Redirect("http://objects.githubusercontent.com/file") };

        Assert.Contains("example.com", Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, elsewhere.Client())).Message);
        Assert.Contains("nowhere", Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, nowhere.Client())).Message);
        Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, plain.Client()));
        Assert.Equal([ReleaseUrl], elsewhere.Requested);
    }

    /// <summary>
    /// Asserts that redirects stop after the hop limit, and that as many as the limit allows are followed.
    /// </summary>
    [Fact]
    public void Get_StopsAfterTheRedirectLimit()
    {
        var endless = new FakeGitHub { [ReleaseUrl] = Redirect(FileUrl + "0") };
        var justEnough = new FakeGitHub { [ReleaseUrl] = Redirect(FileUrl + "0") };

        for (var hop = 0; hop <= ReleaseDownload.MaxRedirects; hop++)
        {
            endless[FileUrl + hop] = Redirect(FileUrl + (hop + 1));
            justEnough[FileUrl + hop] = hop == ReleaseDownload.MaxRedirects - 1 ? File([7]) : Redirect(FileUrl + (hop + 1));
        }

        Assert.Contains("too often", Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, endless.Client())).Message);
        Assert.Equal(ReleaseDownload.MaxRedirects + 1, endless.Requested.Count);
        Assert.Equal([7], ReleaseDownload.Get(ReleaseUrl, justEnough.Client()));
    }

    /// <summary>
    /// Asserts that an answer other than OK, an empty file and a file larger than the relay takes are refused.
    /// </summary>
    [Fact]
    public void Get_RefusesErrorsAndFilesOfTheWrongSize()
    {
        var missing = new FakeGitHub { [ReleaseUrl] = new HttpResponseMessage(HttpStatusCode.NotFound) };
        var empty = new FakeGitHub { [ReleaseUrl] = File([]) };
        var huge = new FakeGitHub { [ReleaseUrl] = File(new byte[ReleaseDownload.MaxScriptBytes + 1]) };

        Assert.Contains("404", Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, missing.Client())).Message);
        Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, empty.Client()));
        Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get(ReleaseUrl, huge.Client()));
    }

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

    /// <summary>
    /// A GitHub inside the test: the answer to each address, and the addresses asked for.
    /// </summary>
    private sealed class FakeGitHub : HttpMessageHandler
    {
        /// <summary>
        /// The answers by address.
        /// </summary>
        private readonly Dictionary<string, HttpResponseMessage> _answers = new(StringComparer.Ordinal);

        /// <summary>
        /// The addresses asked for, in order.
        /// </summary>
        public List<string> Requested { get; } = [];

        /// <summary>
        /// The answer to an address.
        /// </summary>
        /// <param name="url">The address.</param>
        /// <returns>The answer.</returns>
        public HttpResponseMessage this[string url]
        {
            get => _answers[url];
            set => _answers[url] = value;
        }

        /// <summary>
        /// Makes a client that asks this GitHub.
        /// </summary>
        /// <returns>The client.</returns>
        public HttpClient Client() => new(this);

        /// <inheritdoc />
        protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var url = request.RequestUri!.ToString();
            Requested.Add(url);
            return _answers.TryGetValue(url, out var answer) ? answer : new HttpResponseMessage(HttpStatusCode.NotFound);
        }

        /// <inheritdoc />
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(Send(request, cancellationToken));
    }
}
