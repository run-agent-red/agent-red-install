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

`nix/hosted-agent.json` is **auto-maintained** — don't edit it by hand. On every
push to the **extension** repo's `main`, its `images` CI:

1. builds + pushes the agent closure to the `agent-red` Cachix cache (Linux
   arches on the `build` job, Apple-Silicon macOS on the `agent-darwin` job), and
2. the `update-pins` job writes each store path into this repo's
   `nix/hosted-agent.json` and commits — but only when a pin actually changed.

Because the extension's `combinedSrc` is filtered to just the Go build inputs,
the pins only move when the agent genuinely changes (Go code, deps, or a nixpkgs
bump), not on unrelated commits.

One-time setup this automation depends on:

- **`INSTALL_REPO_PAT`** secret on the extension repo: a token with
  `contents:write` on `run-agent-red/agent-red-install` (so CI can commit here).
- The Cachix cache's **"upstream caches" setting is off**, so the full closure
  (incl. `tzdata`/`iana-etc`/`mailcap`) is published — otherwise `fetchClosure`
  can't assemble it.
- The real Cachix public key is set once in `flake.nix`'s
  `nixConfig.extra-trusted-public-keys` (it does not change between releases).
