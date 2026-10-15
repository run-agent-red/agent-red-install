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

## How it works

- `nix/hosted-agent.json` pins the prebuilt agent's per-arch store paths and the
  Cachix cache they live in.
- `flake.nix` exposes `hosted-agent` (the default package) via `fetchClosure`,
  which substitutes those paths from the cache and verifies their signatures
  against the trusted public key — no build, no source.

## Releasing (maintainers)

On each hosted-agent release, the **extension** repo's `images` CI:

1. builds the agent and pushes its closure to the `agent-red` Cachix cache, and
2. prints the per-arch store paths ("hosted-agent pin → …").

Copy those into `nix/hosted-agent.json` here (replacing the `0000…`
placeholders), keep `cache` as `https://agent-red.cachix.org`, and commit. Set
the real Cachix public key in `flake.nix`'s `nixConfig.extra-trusted-public-keys`
once (it does not change between releases).
