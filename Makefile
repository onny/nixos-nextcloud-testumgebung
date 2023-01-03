build:
	git submodule update --init
	# Build server
	cd server && git submodule update --init
	cd server && make dev-setup
	cd server && make build-js
	cd server && npm run sass
	cd calendar && make dev-setup
	cd calendar && make build-js

clean:
	rm nixos.qcow2

run:
	QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::1433-:143,hostfwd=tcp::5877-:587" nixos-shell vm-nextcloud.nix
