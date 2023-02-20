{
  inputs = {
    # FIXME
    #inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs.url = "github:onny/nixpkgs/phpunit";
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
      in
      {
        devShell = pkgs.mkShell {
          packages = with pkgs; [
            phpPackages.composer
            phpunit
            nodejs
          ];
        };
        packages = { inherit start; };
        defaultPackage = start;
      });
  }

