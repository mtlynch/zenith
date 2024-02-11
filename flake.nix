{
  description = "Dev environment for eth-zvm";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # 0.8.21
    solc_dep.url = "github:NixOS/nixpkgs/0a254180b4cad6be45aa46dce896bdb8db5d2930";

    # 0.11.0
    zig_dep.url = "github:NixOS/nixpkgs/46688f8eb5cd6f1298d873d4d2b9cf245e09e88e";
  };

  outputs = { self, flake-utils, solc_dep, zig_dep }@inputs :
    flake-utils.lib.eachDefaultSystem (system:
    let
      solc_dep = inputs.solc_dep.legacyPackages.${system};
      zig_dep = inputs.zig_dep.legacyPackages.${system};
    in
    {
      devShells.default = zig_dep.mkShell {
        packages = [
          solc_dep.solc
          zig_dep.zig
        ];

        shellHook = ''
          echo "solc" "$(solc --version | grep -oP 'Version:\s*\K[^ ]+')"
          echo "zig" "$(zig version)"
        '';
      };
    });
}
