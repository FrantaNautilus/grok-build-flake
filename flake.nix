{
  description = "Nix Flake for Grok Build CLI (x.ai)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      rec {
        packages.grok-build = pkgs.stdenv.mkDerivation rec {
          pname = "grok-build";
          version = "0.2.77"; # Adjust to latest track from x.ai

          src = if system == "x86_64-linux"
            then
              pkgs.fetchurl {
                url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-linux-x86_64";
                sha256 = "0w26grkzfwk92708rg4p989dqb04r3gcjimi63c94ipgdshk6rws";
              }
            else
              pkgs.fetchurl {
                url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-linux-aarch64";
                sha256 = "0dw46ap75cnavg5yha1ibr2fgc8j7i44l835pxf7zqjwhrdw44s9";
              };

          nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
          
          # Dynamic dependencies required by the pre-compiled Go/Rust/C binary
          buildInputs = with pkgs; [
            stdenv.cc.cc.lib
            openssl
            zlib
          ];

          dontUnpack = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp $src $out/bin/grok
            chmod +x $out/bin/grok
            
            # Mirror the original install script behavior of linking the agent alias
            ln -s $out/bin/grok $out/bin/agent
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Grok Build CLI by x.ai";
            homepage = "https://x.ai/cli";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" "aarch64-linux" ];
          };
        };

        packages.default = packages.grok-build;

        # Allows quick execution via `nix run github:youruser/grok-flake`
        apps.default = flake-utils.lib.mkApp { drv = packages.grok-build; };

        # Allows testing inside an ephemeral shell via `nix shell`
        devShells.default = pkgs.mkShell {
          buildInputs = [ packages.grok-build ];
        };
      }
    ) // {
      # Pass a Home Manager module downstream for clean system configuration integration
      homeManagerModules.default = { config, lib, pkgs, ... }: {
        options.programs.grok-build.enable = lib.mkEnableOption "Grok Build CLI";
        config = lib.mkIf config.programs.grok-build.enable {
          home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.grok-build ];
        };
      };
    };
}
