all:
	QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::1433-:143,hostfwd=tcp::2525-:25" NIX_PATH=nixpkgs=/home/onny/projects/nixpkgs nixos-shell vm-nextcloud.nix
