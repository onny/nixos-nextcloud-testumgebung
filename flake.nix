{
  # FIXME
  inputs.nixpkgs.url = "github:onny/nixpkgs/phpunit";
  #inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      start =
        pkgs.writeShellScriptBin "start" ''
          set -e
          export QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::1433-:143,hostfwd=tcp::5877-:587"
          ${pkgs.nixos-shell}/bin/nixos-shell vm-nextcloud.nix
        '';
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          phpPackages.composer
          phpunit
          nixos-shell
          nodejs
        ];
      };
      packages = { inherit start; };
      defaultPackage = start;
    };
}

