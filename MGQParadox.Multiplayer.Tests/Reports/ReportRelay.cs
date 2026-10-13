//----------------------------------------------------------------
//  ReportRelay.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// A relay's bug report route inside the test process: it keeps every request and answers each
/// with the status and JSON the test sets, optionally holding the answer back until released.
/// </summary>
internal sealed class ReportRelay : IDisposable
{
    /// <summary>
    /// Serves the requests, on a free port of this PC.
    /// </summary>
    private readonly HttpListener _listener = new();

    /// <summary>
    /// Guards <see cref="_requests"/>.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The requests taken so far.
    /// </summary>
    private readonly List<ReportRequest> _requests = [];

    /// <summary>
    /// Starts the relay.
    /// </summary>
    public ReportRelay()
    {
        var probe = new TcpListener(IPAddress.Loopback, 0);
        probe.Start();
        var port = ((IPEndPoint)probe.LocalEndpoint).Port;
        probe.Stop();

        _listener.Prefixes.Add($"http://localhost:{port}/");
        _listener.Start();
        Address = new Uri($"ws://localhost:{port}");
        _ = Task.Run(AcceptAllAsync);
    }

    /// <summary>
    /// The relay's address, as a relay lookup hands it out.
    /// </summary>
    public Uri Address { get; }

    /// <summary>
    /// The status every request is answered with.
    /// </summary>
    public int Status { get; set; } = 201;

    /// <summary>
    /// The JSON every request is answered with.
    /// </summary>
    public string Answer { get; set; } = """{"issue": 42, "url": "https://github.com/Pauliinchen/MGQ-Online/issues/42", "id": "2026-10-11-0123abcd"}""";

    /// <summary>
    /// Holds every answer back until set; set from the start.
    /// </summary>
    public ManualResetEventSlim Release { get; } = new(true);

    /// <summary>
    /// The requests taken so far, in order.
    /// </summary>
    public ReportRequest[] Requests
    {
        get
        {
            lock (_gate)
            {
                return [.. _requests];
            }
        }
    }

    /// <inheritdoc />
    public void Dispose()
    {
        Release.Set();
        _listener.Stop();
    }

    /// <summary>
    /// Takes requests until the relay stops.
    /// </summary>
    /// <returns>Completes once the relay stopped.</returns>
    private async Task AcceptAllAsync()
    {
        while (_listener.IsListening)
        {
            HttpListenerContext context;

            try
            {
                context = await _listener.GetContextAsync();
            }
            catch
            {
                return;
            }

            _ = Task.Run(() => Serve(context));
        }
    }

    /// <summary>
    /// Keeps a request and answers it.
    /// </summary>
    /// <param name="context">The request.</param>
    private void Serve(HttpListenerContext context)
    {
        try
        {
            using var body = new MemoryStream();
            context.Request.InputStream.CopyTo(body);

            lock (_gate)
            {
                _requests.Add(new ReportRequest(
                    context.Request.HttpMethod,
                    context.Request.Url!.AbsolutePath,
                    context.Request.Headers["X-MGQ-Player"],
                    context.Request.Headers["X-MGQ-Features"],
                    context.Request.ContentType,
                    body.ToArray()));
            }

            Release.Wait(TimeSpan.FromSeconds(30));

            var answer = Encoding.UTF8.GetBytes(Answer);
            context.Response.StatusCode = Status;
            context.Response.ContentType = "application/json";
            context.Response.OutputStream.Write(answer);
            context.Response.Close();
        }
        catch
        {
            // A stopped relay drops what it was answering.
        }
    }
}

/// <summary>
/// A request the report relay took.
/// </summary>
/// <param name="Method">Its method.</param>
/// <param name="Path">Its path.</param>
/// <param name="Player">Its X-MGQ-Player header.</param>
/// <param name="Features">Its X-MGQ-Features header.</param>
/// <param name="ContentType">Its content type.</param>
/// <param name="Body">Its body.</param>
internal sealed record ReportRequest(string Method, string Path, string? Player, string? Features, string? ContentType, byte[] Body);
