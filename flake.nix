{
  description = "Dev environment for eth-zvm";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    zls_dep.url = "github:NixOS/nixpkgs/160b762eda6d139ac10ae081f8f78d640dd523eb";

    # 0.11.0
    zig_dep.url = "github:NixOS/nixpkgs/46688f8eb5cd6f1298d873d4d2b9cf245e09e88e";
  };

  outputs = { self, flake-utils, zig_dep, zls_dep }@inputs :
    flake-utils.lib.eachDefaultSystem (system:
    let
      zig_dep = inputs.zig_dep.legacyPackages.${system};
      zls_dep = inputs.zls_dep.legacyPackages.${system};
    in
    {
      devShells.default = zig_dep.mkShell {
        packages = [
          zig_dep.xxd
          zig_dep.zig
          zls_dep.zls
          zls_dep.valgrind
        ];

        shellHook = ''
          xxd --version 2>&1
          echo 'zls' "$(zls --version)"
          echo 'zig' "$(zig version)"
        '';
      };
    });
}
