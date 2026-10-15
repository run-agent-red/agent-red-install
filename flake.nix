{
  description =
    "Public installer for the hosted agent-red: fetches the prebuilt, signed binary from Cachix — no access to the private source needed.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # So `nix run github:run-agent-red/agent-red-install --accept-flake-config`
  # pulls the binary from the public cache automatically. The web-app deploy
  # recipe also passes these explicitly, so --accept-flake-config is optional.
  # Keep the key in sync with nix/hosted-agent.json's cache.
  nixConfig = {
    extra-substituters = [ "https://agent-red.cachix.org" ];
    extra-trusted-public-keys = [
      "agent-red.cachix.org-1:9A0eteN1sI4xoAyvCcWqdR9rBPtc0r6GFgp1rC1TInc="
    ];
    # NOTE: the hosted-agent output uses builtins.fetchClosure, gated behind the
    # `fetch-closure` experimental feature. That is an EVAL-time builtin, so it
    # cannot be enabled from here (nixConfig is applied too late). The caller must
    # enable it, e.g. `--extra-experimental-features 'nix-command flakes
    # fetch-closure'` or in nix.conf. The web-app deploy recipe passes it.
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # The pin the extension release CI publishes: the prebuilt hosted agent's
      # per-arch store paths in the public Cachix cache. This repo has no agent
      # source — it only fetches the already-built, signed closure.
      pin = builtins.fromJSON (builtins.readFile ./nix/hosted-agent.json);

      perSystem = system:
        let
          pkgs = import nixpkgs { inherit system; };
          hosted-agent = pkgs.symlinkJoin {
            name = "hosted-agent";
            paths = [
              (builtins.fetchClosure {
                fromStore = pin.cache;
                fromPath = pin.${system};
                inputAddressed = true;
              })
            ];
            # So `nix run` launches the agent binary.
            meta.mainProgram = "agent-red";
          };
        in
        {
          default = hosted-agent;
          inherit hosted-agent;
        };
    in
    {
      packages = forAllSystems perSystem;
    };
}
