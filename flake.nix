{
  description = "Dev environment for zenith";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls-overlay.url = "github:zigtools/zls";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachSystem (builtins.attrNames inputs.zig-overlay.packages) (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            zigpkgs = inputs.zig-overlay.packages.${prev.system};
          })
        ];
      };
      zigVersion = "0.13.0";
      zig = pkgs.zigpkgs.${zigVersion};
      zls = inputs.zls-overlay.packages.${system}.zls.overrideAttrs (old: {
        nativeBuildInputs = [ zig ];
      });

      mkScript = name: text: pkgs.writeShellScriptBin name ''
        set -eux
        ${text}
      '';
    in
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          xxd
          zig
          zls
        ];

        shellHook = ''
          xxd --version 2>&1
          echo 'zls' "$(zls --version)"
          echo 'zig' "$(zig version)"
        '';
      };

      apps = {
        test = flake-utils.lib.mkApp {
          drv = mkScript "test" ''
            ${zig}/bin/zig build test --summary all
          '';
        };

        build-release-safe = flake-utils.lib.mkApp {
          drv = mkScript "build-release-safe" ''
            ${zig}/bin/zig build -Doptimize=ReleaseSafe --verbose
          '';
        };

        build-release-fast = flake-utils.lib.mkApp {
          drv = mkScript "build-release-fast" ''
            ${zig}/bin/zig build -Doptimize=ReleaseFast --verbose
          '';
        };

        compile-testcases = flake-utils.lib.mkApp {
          drv = mkScript "compile-testcases" ''
            ${zig}/bin/zig build -Doptimize=ReleaseSafe --verbose
            ./dev-scripts/compile-testcases
          '';
        };

        benchmark = flake-utils.lib.mkApp {
          drv = mkScript "benchmark" ''
            ${zig}/bin/zig build -Doptimize=ReleaseFast --verbose
            ./dev-scripts/compile-testcases
            dev-scripts/benchmark-all-inputs ./zig-out/bin/zenith 30
          '';
        };
      };
    });
}
