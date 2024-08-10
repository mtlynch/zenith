{
  description = "Dev environment for zenith";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # 0.13.0
    zls_dep.url = "github:NixOS/nixpkgs/c3392ad349a5227f4a3464dce87bcc5046692fce";

    # 0.13.0
    zig_dep.url = "github:NixOS/nixpkgs/ed0af8c19f55bede71dc9c2002185cf228339901";
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
        ];

        shellHook = ''
          xxd --version 2>&1
          echo 'zls' "$(zls --version)"
          echo 'zig' "$(zig version)"
        '';
      };
    });
}
