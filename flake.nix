{
  description = "Spawns lightweight nixos vm in a shell";

  inputs = {
    # FIXME
    #nixpkgs.url = "nixpkgs/nixos-24.05";
    nixpkgs.url = "github:onny/nixpkgs/hmr-enabler";
    nixos-shell.url = "github:Mic92/nixos-shell";
    keycloak-realms.url = "github:rorosen/nixpkgs/keycloak-realm-import";
  };

  outputs = { self, nixpkgs, nixos-shell, ... }@inputs: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    start =
      pkgs.writeShellScriptBin "start" ''
        set -e
        export QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::8081-:8081,hostfwd=tcp::1433-:143,hostfwd=tcp::5877-:587"
        ${pkgs.nixos-shell}/bin/nixos-shell --flake .
       '';
  in {

    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs.inputs = inputs;
      modules = [
        (import ./vm-nextcloud.nix)
        nixos-shell.nixosModules.nixos-shell
      ];
    };

    devShells.x86_64-linux = {
      default = with pkgs; mkShell {
        nativeBuildInputs = [
          php83Packages.composer
          phpunit
          nodejs
          nodePackages.rollup
          act
          npm-check-updates
        ];
      };
    };

    packages = { inherit start; };
    defaultPackage.x86_64-linux = start;

  };
}

