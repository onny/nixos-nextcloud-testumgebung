# Todo
# - Creating symlink to config dir
# - Patch chgrp in Nextcloud module

{ pkgs, config, lib, options, ... }: {

  # FIXME
  disabledModules = [
    "services/web-apps/nextcloud.nix"
    "services/mail/maddy.nix"
  ];
  imports = [
    ./nextcloud.nix
    "${fetchTarball "https://github.com/onny/nixpkgs/archive/maddy-acc.tar.gz"}/nixos/modules/services/mail/maddy.nix"
  ];

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard and password policy check from Nextcloud
        # package
        nextcloud25 = super.nextcloud25.overrideAttrs (oldAttrs: rec {
          patches = [];
          src = ./server;
          installPhase = oldAttrs.installPhase + ''
            mkdir -p $out/
            cp -R . $out/
            #rm -r $out/apps/firstrunwizard
            #rm -r $out/apps/password_policy
          '';
          dontBuild = true;
        });
      })
    ];
  };

  # Setup Nextcloud including apps
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud25;
    hostName = "localhost";
    extraApps = with pkgs.nextcloud25Packages.apps; {
      inherit calendar;
    };
    extraAppsEnable = true;
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "adminpass" "test123"}";
    };
    caching.apcu = false;
    phpPackage = lib.mkForce (pkgs.php.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with all; [
        xdebug
      ]));
    });
    phpOptions = {
      "xdebug.mode" = "debug";
      "xdebug.client_host" = "10.0.2.2";
      "xdebug.client_port" = "9000";
      "xdebug.start_with_request" = "yes";
      "xdebug.idekey" = "ECLIPSE";
    };
    appstoreEnable = false;
    extraOptions = {
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";
      debug = true;
      logLevel = 0;
      trusted_domains = [ "10.100.100.1" ];
      apps_paths = [
        {
          path = "/var/lib/nextcloud/nix-apps";
          url = "/nix-apps";
          writeable = false;
        }
        {
          path = "/var/lib/nextcloud/server/apps";
          url = "/apps";
          writeable = false;
        }
      ];
    };
  };
  # Mount our local development repositories into the VM
  nixos-shell.mounts.extraMounts = {
    "/var/lib/nextcloud/server" = {
      target = ./server;
      cache = "none";
    };
    # FIXME
    #"/var/lib/nextcloud/server/apps/calendar" = {
    #   target = ./calendar;
    #   cache = "none";
    #};
    "/var/lib/nextcloud/server/3rdparty/sabre/dav" = {
       target = ./dav;
       cache = "none";
    };
  };
  services.nginx.virtualHosts."localhost".root = lib.mkForce "/var/lib/nextcloud/server";

  # Setup mail server
  services.maddy = {
    enable = true;
    hostname = "localhost";
    primaryDomain = "localhost";
    localDomains = [ "$(primary_domain)" "10.100.100.1" ];
    # Disable any sender validation checks
    config = lib.concatStrings (
      builtins.match "(.*)authorize_sender.*identity\n[ ]+\}(.*)" options.services.maddy.config.default
    );
    ensureAccounts = [
      "user1@localhost"
      "user2@localhost"
      "admin@localhost"
    ];
  };

  # Configure local mail delivery
  programs.msmtp = {
    enable = true;
    accounts.default = {
      host = "localhost";
      port = 587;
      auth = "login";
      tls = "off";
      from = "admin@localhost";
      user = "admin@localhost";
      password = "test123";
    };
  };

  # Creating mail users and inboxes
  # FIXME: Upstream
  systemd.services.maddy-accounts = {
    script = ''
      #!${pkgs.runtimeShell}

      if ! ${pkgs.maddy}/bin/maddyctl creds list | grep "user1@localhost"; then
        ${pkgs.maddy}/bin/maddyctl creds create --password test123 user1@localhost
      fi
      if ! ${pkgs.maddy}/bin/maddyctl creds list | grep "user2@localhost"; then
        ${pkgs.maddy}/bin/maddyctl creds create --password test123 user2@localhost
      fi
      if ! ${pkgs.maddy}/bin/maddyctl creds list | grep "admin@localhost"; then
        ${pkgs.maddy}/bin/maddyctl creds create --password test123 admin@localhost
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "maddy";
    };
    after = [ "maddy.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  # Creating Nextcloud users and configure mail adresses
  systemd.services.nextcloud-add-user = {
    script = ''
      export OC_PASS="test123"
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:add --password-from-env user1
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting user1 settings email "user1@localhost"
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:add --password-from-env user2
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting user2 settings email "user2@localhost"
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting admin settings email "admin@localhost"

      ${config.services.nextcloud.occ}/bin/nextcloud-occ app:enable calendar

      rm /var/lib/nextcloud/apps
      ln -s /var/lib/nextcloud/server/apps /var/lib/nextcloud/apps
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "nextcloud";
    };
    after = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  # Required for php unit testing
  environment.systemPackages = [ pkgs.php ];
  # FIXME Package phpunit?
  # Inside /var/lib/nextcloud/server run
  # composer require phpunit/phpunit
  environment.interactiveShellInit = ''
    export PATH="$PATH:/var/lib/nextcloud/server/lib/composer/bin"
  '';

  system.stateVersion = "22.11";

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
