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
      zigVersion = "master-2025-01-20";
      zig = pkgs.zigpkgs.${zigVersion};
      zls = inputs.zls-overlay.packages.${system}.zls.overrideAttrs (old: {
        nativeBuildInputs = [ zig ];
      });
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
    });
}
