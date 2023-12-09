{
  inputs = {
    nixpkgs.url = "nixpkgs/23.11";
    # Required for multi platform support
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        start =
          pkgs.writeShellScriptBin "start" ''
            set -e
            export QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::1433-:143,hostfwd=tcp::5877-:587"
            ${pkgs.nixos-shell}/bin/nixos-shell vm-nextcloud.nix
          '';
        phpunit = pkgs.phpunit.overrideAttrs (oldAttrs: rec {
          version = "9.6.13";
          src = pkgs.fetchurl {
            url = "https://phar.phpunit.de/phpunit-${version}.phar";
            hash = "sha256-1nxGBJCGBPQMyA91xbVd8baFoGoeqBkf7feFMcxdAeU=";
          };
        });
      in
      {
        devShell = pkgs.mkShell {
          packages = with pkgs; [
            php82Packages.composer
            phpunit
            nodejs
            nodePackages.rollup
          ];
        };
        packages = { inherit start; };
        defaultPackage = start;
      });
  }

