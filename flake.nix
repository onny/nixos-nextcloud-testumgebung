{
  # FIXME
  inputs.nixpkgs.url = "github:onny/nixpkgs/phpunit";
  #inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          phpPackages.composer
          phpPackages.phpunit
          nixos-shell
          nodejs
        ];
      };
    };
}

