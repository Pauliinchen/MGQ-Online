# ServerCoreProbe

A throwaway probe for refactor phase 0.1: can the battle server load a linux-x64 NativeAOT shared
library of ours through Fiddle in a forked, sandboxed battle child, the way `MGQOnline.ServerCore`
is planned? Results: "MGQ Online refactor probes.md" in the workspace, section "Battle server
library (probe 0.1a)".

| File | What |
|---|---|
| `Exports.cs`, `ServerCoreProbe.csproj` | The library: `core_open` (handshake, answers 1), `core_echo` (copies a byte buffer), `core_info` (runtime and GC settings), `core_stress` (makes the GC run, keeps memory up to a size, runs the finalizer and a thread). |
| `build.ps1`, `container-build.sh` | Builds the library twice (plain, and `.baked.so` with a 256 MB GC heap limit baked in) in the pinned `mcr.microsoft.com/dotnet/sdk:10.0-noble-aot` image (Ubuntu 24.04, glibc 2.39; the library needs GLIBC_2.34), and packs the VPS kit `out/server-core-probe.tar.gz`. |
| `probe.rb` | Plays the battle server's children: forks as `server.rb` does, loads the library, enters `BattleServer/lib/sandbox.rb` itself and calls the exports, in nine orders. The parent measures each child from `/proc` at its marks. |
| `probe-local.ps1` | Runs the kit in a privileged Ubuntu 26.04 container with `ruby3.3` from apt, as on the VPS. |
| `vps/run.sh` | The kit's entry on the VPS. |

## Running it

On this PC (Docker Desktop running):

```powershell
.\build.ps1
.\probe-local.ps1
```

On the VPS, from Git Bash on this PC after `build.ps1`:

```bash
ssh -i ~/.ssh/mgq_relay mgqadmin@169.58.30.251 'rm -rf /tmp/server-core-probe && tar -C /tmp -xzf - && sudo bash /tmp/server-core-probe/run.sh' < tools/ServerCoreProbe/out/server-core-probe.tar.gz
```

The kit unpacks into `/tmp/server-core-probe` only and deletes it at the end. It runs the probe as
root, as the battle server runs, reads the running battle server parent's `VmSize` from `/proc` to
start its children with the same address space, and touches nothing of the battle server, the
relay or their files and settings. Its children run as `nobody`, so they share the sandbox's
1024-thread budget with the live battles for a few seconds.
