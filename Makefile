all:
	QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::1433-:143,hostfwd=tcp::5877-:587" nixos-shell vm-nextcloud.nix
