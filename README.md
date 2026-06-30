# grok-build-flake

A [Nix flake](https://wiki.nixos.org/wiki/Flakes) that installs the [Grok Build CLI](https://x.ai/cli) on NixOS and other Nix-based Linux systems.

The official installer (`curl -fsSL https://x.ai/cli/install.sh | bash`) downloads a pre-built binary and places it under `~/.grok/`. That approach does not work on NixOS because it writes outside the Nix store, mutates shell config, and the binary expects dynamic libraries that are not available in a conventional FHS layout. This flake provides a Nix-native equivalent: it fetches the **same official binaries** from xAI's public artifact bucket, patches them for NixOS with `autoPatchelfHook`, and exposes them as a normal Nix package.

## What this flake provides

| Output | Description |
|--------|-------------|
| `packages.<system>.grok-build` | The Grok Build CLI binary (`grok`) plus an `agent` symlink, matching the official install script |
| `packages.<system>.default` | Alias for `grok-build` |
| `apps.<system>.default` | Run without installing: `nix run github:FrantaNautilus/grok-build-flake` |
| `devShells.<system>.default` | Ephemeral shell with `grok` on `PATH` |
| `homeManagerModules.default` | Home Manager option `programs.grok-build.enable` |

**Supported platforms:** `x86_64-linux`, `aarch64-linux`

There is no dedicated NixOS system module. For system-wide installation, add the package to `environment.systemPackages` (see below). Per-user setup is best done through the Home Manager module.

## Quick start

### Run without installing

```bash
nix run github:FrantaNautilus/grok-build-flake
```

### Install to your user profile

```bash
nix profile install github:FrantaNautilus/grok-build-flake
```

After installation, run `grok` or `agent`. Authenticate with `grok login` as described in the [official docs](https://docs.x.ai/build/overview).

## Unfree software

The Grok Build CLI is proprietary software distributed by xAI. The package is marked `unfree` in Nixpkgs metadata, so you must allow unfree packages:

```nix
# configuration.nix or flake nixpkgs overlay
nixpkgs.config.allowUnfree = true;
```

Or, for a one-off install:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix profile install github:FrantaNautilus/grok-build-flake
```

This requirement reflects xAI's licensing of the binary, not an extra restriction introduced by this flake.

## Home Manager

Add the flake as an input, then import the module and enable the program:

```nix
{
  inputs.grok-build-flake.url = "github:FrantaNautilus/grok-build-flake";

  # flake.nix (excerpt)
  outputs = { self, nixpkgs, home-manager, grok-build-flake, ... }: {
    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      modules = [
        grok-build-flake.homeManagerModules.default
        {
          programs.grok-build.enable = true;
        }
      ];
    };
  };
}
```

This adds `grok-build` to `home.packages`, making `grok` and `agent` available in your user environment.

## NixOS (system-wide)

Use the flake as an input and reference the package directly:

```nix
{
  inputs.grok-build-flake.url = "github:FrantaNautilus/grok-build-flake";

  outputs = { self, nixpkgs, grok-build-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;
          environment.systemPackages = [
            grok-build-flake.packages.${pkgs.stdenv.hostPlatform.system}.grok-build
          ];
        })
      ];
    };
  };
}
```

For a single-user machine, the Home Manager module is usually simpler and keeps CLI tools in the user profile.

## Development environment

To try the CLI in an ephemeral shell (useful for testing or hacking on this flake):

```bash
git clone https://github.com/FrantaNautilus/grok-build-flake.git
cd grok-build-flake
nix develop
```

Inside the shell, `grok` and `agent` are on `PATH`. No files are written to `~/.grok/` by the flake itself; run `grok login` if you need authentication.

## What this flake does and does not do

### What it does (mirrors the install script's core behavior)

- Downloads the official pre-built binary from `storage.googleapis.com/grok-build-public-artifacts/cli/` (the same source the install script falls back to)
- Installs `grok` and an `agent` symlink pointing to it
- Patches the binary so it runs on NixOS (`autoPatchelfHook` + required `buildInputs`)

### What it does not do (differs from the full install script)

The official `install.sh` also configures shell `PATH`, generates completions, writes `~/.grok/config.toml`, and handles deployment keys. This flake intentionally does **only** the binary delivery part. After installing via Nix:

- **Authentication** — run `grok login` (stores credentials in `~/.grok/auth.json` as usual)
- **Shell completions** — generate manually if desired: `grok completions bash`, `grok completions zsh`, etc.
- **Updates** — bump `version` and `sha256` in `flake.nix`, then rebuild

## Not a repackaging — terms of use

This flake is **not** a fork, rebuild, or modification of the Grok Build CLI source code. It does not reverse-engineer, decompile, or redistribute a altered binary. It is a thin Nix packaging layer that:

1. Fetches the unmodified official binary published by xAI
2. Applies standard NixOS dynamic-linker patching so the binary can execute
3. Places the result in the Nix store

Functionally, it replaces the download-and-link step of `install.sh` for environments where that script cannot work. The CLI still phones home to xAI's services, still requires a valid subscription (SuperGrok or X Premium+), and is still governed by [xAI's terms](https://x.ai/legal/terms-of-service). No xAI software is being redistributed under a different license or brand.

## Updating the packaged version

When a new CLI release ships, update `version` and the corresponding `sha256` in `flake.nix`:

```nix
version = "0.2.77"; # match the release you want

# x86_64-linux
sha256 = "..."; # from nix-prefetch-url or a failed build

# aarch64-linux
sha256 = "...";
```

Prefetch a hash:

```bash
nix store prefetch-file \
  "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-VERSION-linux-x86_64"
```

Or run a build and copy the `got:` hash from the error message.

## License

The flake definitions in this repository are open source. The `grok-build` package itself is **unfree** proprietary software owned by xAI.