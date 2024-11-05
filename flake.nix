{
  description = "Spawns lightweight nixos vm in a shell";

  inputs = {
    # FIXME
    #nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs.url = "nixpkgs/master";
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
      ];
    };

    devShells.x86_64-linux = {
      default = with pkgs; mkShell {
        # FIXME "composer lint" only works with PHP 8.2 at the moment
        nativeBuildInputs = with php84Packages; [
	  php84
          composer
          php-cs-fixer
          phpunit
          nodejs
          nodePackages.rollup
          act
	  psalm
          npm-check-updates
          licensedigger
	  reuse
          #(eslint.overrideAttrs (oldAttrs: rec {
          #  version = "8.57.0";
          #  src = fetchFromGitHub {
          #    owner = "eslint";
          #    repo = "eslint";
          #    rev = "refs/tags/v${version}";
          #    hash = "sha256-nXlS+k8FiN7rbxhMmRPb3OplHpl+8fWdn1nY0cjL75c=";
          #  };
          #  postPatch = ''
          #    cp ${./package-lock.json} package-lock.json
          #  '';
          #  npmDepsHash = "sha256-DiXgAD0PvIIBxPAsdU8OOJIyvYI0JyPqu6sj7XN94hE=";
          #  npmDeps = pkgs.fetchNpmDeps {
          #    src = lib.fileset.toSource {
          #      root = ./.;
          #      fileset = lib.fileset.unions [
          #        ./package-lock.json
          #        ./package.json
          #      ];
          #    };
          #    name = "eslint-${version}-npm-deps";
          #    hash = npmDepsHash;
          #  };
          #}))
        ];
      };
    };

    packages = { inherit start; };
    defaultPackage.x86_64-linux = start;

  };
}

