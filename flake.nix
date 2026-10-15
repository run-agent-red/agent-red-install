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
      "agent-red.cachix.org-1:REPLACE_WITH_CACHIX_PUBLIC_KEY"
    ];
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
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
              (pkgs.fetchClosure {
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
