# agent-red-install

A tiny **public** installer for the hosted agent-red. It contains no agent source
— just a flake that fetches the already-built, **signature-verified** agent
binary from the public Cachix cache (`agent-red.cachix.org`). This lets anyone
install and run the native (non-container) agent without access to the private
`agent-red` / `extension` source.

## Use it

```bash
nix run github:run-agent-red/agent-red-install -- <agent flags>
```

The web-app's deploy console generates the full command (tailnet key, SSH keys,
flags) for you under the **nix** deploy method; this repo is what that command
points at. It also passes the cache substituter + trusted key explicitly, so you
do not need `--accept-flake-config`. Running it by hand instead:

```bash
nix run --accept-flake-config github:run-agent-red/agent-red-install -- -h
```

Requirements: Nix with flakes enabled. The binary runs on the host with no
container boundary, so it can reach the host itself — use it when the host is in
scope (local assessment / pivot), ideally on a dedicated or disposable machine.

## Platforms

| Host | Native `nix run` | Docker |
| --- | --- | --- |
| Linux (x86_64 / aarch64) | ✅ full agent | ✅ |
| macOS Apple Silicon (aarch64) | ✅ bare agent¹ | ✅ |
| macOS Intel (x86_64) | — ² | ✅ |
| Windows | — ³ | ✅ |

¹ The offensive toolkit is Linux only, so the native macOS agent is the bare
agent (no baked toolkit). Use Docker (or a Linux host) for the full toolkit.

² nixpkgs 26.11 dropped `x86_64-darwin` support (and GitHub's Intel macOS runners
retire in Fall 2027), so there is no native Intel-mac build. Intel Macs use the
Docker image.

³ Nix has no native Windows build. On Windows use the Docker image, or run the
Linux path under WSL2 (which is Linux Nix — `nix run` works there unchanged).

### Docker (any host, with optional gVisor sandbox)

The container image works on every host, including Windows:

```bash
docker run --rm -it ghcr.io/run-agent-red/agent-red:latest -- -h
# optional gVisor runtime for a stronger sandbox (Linux runtime; requires runsc):
docker run --rm -it --runtime=runsc ghcr.io/run-agent-red/agent-red:latest -- -h
```

## How it works

- `nix/hosted-agent.json` pins the prebuilt agent's per-arch store paths and the
  Cachix cache they live in.
- `flake.nix` exposes `hosted-agent` (the default package) via `fetchClosure`,
  which substitutes those paths from the cache and verifies their signatures
  against the trusted public key — no build, no source.

## Releasing (maintainers)

On each hosted-agent release, the **extension** repo's `images` CI:

1. builds the agent and pushes its closure to the `agent-red` Cachix cache
   (Linux arches on the `build` job, macOS arches on the `agent-darwin` job), and
2. prints each store path ("hosted-agent pin → …"), keyed by Nix system.

Copy those into `nix/hosted-agent.json` here (replacing the `0000…`
placeholders), keep `cache` as `https://agent-red.cachix.org`, and commit. Take
each path from the run that **actually pushed** to Cachix — store paths change
whenever nixpkgs or the source moves, so a path from a non-pushing run will 404.
Confirm one is live before committing:

```bash
h=$(basename <store-path> | cut -d- -f1)
curl -s -o /dev/null -w "%{http_code}\n" "https://agent-red.cachix.org/$h.narinfo"  # 200 = present
```

Set the real Cachix public key in `flake.nix`'s
`nixConfig.extra-trusted-public-keys` once (it does not change between releases).
