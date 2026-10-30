//----------------------------------------------------------------
//  EnteringTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Entered without the parking
//                            - Built the requests without this game's data, which entering compares once the world's mods loaded
//      Paulinchen  2026-10-23: Built the world screen's requests from its forms
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// Registers the world screen's steps (<see cref="WorldEntering"/>) over the world directory, the
/// worlds on this PC.
/// </summary>
internal static class EnteringTopics
{
    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="services">What the topics of worlds share.</param>
    /// <param name="worlds">The worlds on this PC.</param>
    /// <param name="lists">The player's lists of worlds.</param>
    /// <param name="forms">The world screen's open forms, whose values the requests are built from.</param>
    public static void Register(BridgeContext context, WorldServices services, LocalWorlds worlds, WorldLists lists, FormTopics forms)
    {
        WorldEntering entering = new(context, new Directory(services.Directory), worlds, lists, services.Player.Share, services.Tickets, services.Changes);
        entering.UseRequests(forms.FormIn, Clipboard.SetText);
        entering.Register();
    }

    /// <summary>
    /// The world directory as the steps reach it.
    /// </summary>
    /// <param name="directory">Gives the world directory.</param>
    private sealed class Directory(Func<WorldDirectory> directory) : IEnteringDirectory
    {
        /// <inheritdoc />
        public (string State, ListedWorld? World) Listed(string id) => directory().ListedNow(id);

        /// <inheritdoc />
        public void Open(string id) => directory().Open(id);

        /// <inheritdoc />
        public bool Read(string id) => directory().Read(id);

        /// <inheritdoc />
        public bool Unlock(string id, string password) => directory().Unlock(id, password);

        /// <inheritdoc />
        public bool UnlockWithCode(string code) => directory().UnlockWithCode(code);

        /// <inheritdoc />
        public bool FetchStart(string code, string folder) => directory().FetchStart(code, folder);

        /// <inheritdoc />
        public bool SetData(string id, string data) => directory().SetData(id, data);

        /// <inheritdoc />
        public (string State, string? Error) Action()
        {
            (string state, _, string? error) = directory().ActionNow();
            return (state, error);
        }

        /// <inheritdoc />
        public (string Code, string? World, string? Name, string? Start, bool Choose)? Result() => directory().ResultNow();

        /// <inheritdoc />
        public void Clear() => directory().ClearAction();

        /// <inheritdoc />
        public void Refresh(IReadOnlyList<string> added)
        {
            directory().Watch(added);
            directory().Refresh();
        }

        /// <inheritdoc />
        public bool Create(string name, string password, int seats, bool hidden, bool choose, IReadOnlyList<(string Name, string Path)> start, WorldAbout about, string type, string share, int? difficulty, bool otherModsOff, string? squad, bool? raidBosses) =>
            directory().Create(name, password, seats, hidden, choose, start, about, type, share, difficulty, otherModsOff, squad, raidBosses);

        /// <inheritdoc />
        public bool Edit(string id, int seats, string description, string mods, string? modHashes, int? difficulty, bool? otherModsOff, string? squad, bool? raidBosses) =>
            directory().Edit(id, seats, description, mods, modHashes, difficulty, otherModsOff, squad, raidBosses);

        /// <inheritdoc />
        public bool SetSettings(string id, string settings) => directory().SetSettings(id, settings);

        /// <inheritdoc />
        public bool Find(string id) => directory().Find(id);

        /// <inheritdoc />
        public bool Delete(string id) => directory().Delete(id);

        /// <inheritdoc />
        public bool Ban(string id, string target) => directory().Ban(id, target);
    }
}
