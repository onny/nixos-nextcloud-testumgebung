all:
	QEMU_NET_OPTS="hostfwd=tcp::80-:80" NIX_PATH=nixpkgs=/home/onny/projects/nixpkgs nixos-shell vm-nextcloud.nix
