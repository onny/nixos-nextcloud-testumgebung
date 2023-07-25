# Todo
# - Creating symlink to config dir
# - Patch chgrp in Nextcloud module

{ pkgs, config, lib, options, ... }: {

  virtualisation = {
    memorySize = 8000;
    cores = 4;
  };

  # FIXME
  disabledModules = [
    "services/web-apps/nextcloud.nix"
  ];
  imports = [
    ./nextcloud.nix  ];

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard and password policy check from Nextcloud
        # package
        nextcloud27 = super.nextcloud27.overrideAttrs (oldAttrs: rec {
          #patches = [];
          #src = ./server;
          installPhase = oldAttrs.installPhase + ''
            mkdir -p $out/
            cp -R . $out/
            rm -r $out/apps/firstrunwizard
            rm -r $out/apps/password_policy
            rm -r $out/apps/circles
          '';
          dontBuild = true;
        });
      })
    ];
  };

  # Setup Nextcloud including apps
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud27;
    hostName = "localhost";
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit calendar contacts;
    };
    extraAppsEnable = true;
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "adminpass" "test123"}";
    };
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
    configureRedis = true;
    caching.apcu = false;
    extraOptions = {
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";
      log_type = "syslog";
      syslog_tag = "Nextcloud";
      loglevel = 0;
      trusted_domains = [ "10.100.100.1" ];
      phpOptions = {
        short_open_tag = "Off";
        expose_php = "Off";
        error_reporting = "E_ALL & ~E_DEPRECATED & ~E_STRICT";
        display_errors = "stderr";
        "opcache.enable_cli" = "1";
        "opcache.enable" = "1";
        "opcache.interned_strings_buffer" = "12";
        "opcache.max_accelerated_files" = "10000";
        "opcache.memory_consumption" = "128";
        "opcache.save_comments" = "1";
        "opcache.revalidate_freq" = "1";
        "opcache.fast_shutdown" = "1";
        "openssl.cafile" = "/etc/ssl/certs/ca-certificates.crt";
        catch_workers_output = "yes";
      };
      apps_paths = [
        {
          path = "/var/lib/nextcloud/nix-apps";
          url = "/nix-apps";
          writable = false;
        }
        {
          path = "/var/lib/nextcloud/apps";
          url = "/apps";
          writable = false;
        }
        {
          path = "/var/lib/nextcloud/dev-apps";
          url = "/dev-apps";
          writable = false;
        }
      ];
    };
  };
  # Mount our local development repositories into the VM
  nixos-shell.mounts.extraMounts = {
    "/var/lib/nextcloud/dev-apps/circles" = {
       target = ./circles;
       cache = "none";
    };
  };
  #  #"/var/lib/nextcloud/server" = {
  #  #  target = ./server;
  #  #  cache = "none";
  #  #};
  #};
  #};
  #   "/var/lib/nextcloud/server/apps/calendar" = {
  #      target = ./calendar;
  #      cache = "none";
  #   };
  #   "/var/lib/nextcloud/server/apps/activity" = {
  #      target = ./activity;
  #      cache = "none";
  #   };
  #   "/var/lib/nextcloud/server/3rdparty/sabre/dav" = {
  #      target = ./dav;
  #      cache = "none";
  #   };
  #services.nginx.virtualHosts."localhost".root = lib.mkForce "/var/lib/nextcloud/server";

  # Setup mail server
  services.maddy = {
    enable = true;
    hostname = "localhost";
    primaryDomain = "localhost";
    localDomains = [
      "$(primary_domain)"
      "10.0.2.0/24"
      "10.100.100.1"
      "127.0.0.1"
    ];
    # Disable any sender vhttps://github.com/obsidiansystems/ipfs-nix-guide/alidation checks
    config = lib.concatStrings (
      builtins.match "(.*)authorize_sender.*identity\n[ ]+\}(.*)" options.services.maddy.config.default
    );
    ensureAccounts = [
      "user1@localhost"
      "user2@localhost"
      "admin@localhost"
    ];
    ensureCredentials = {
      "user1@localhost".passwordFile = "${pkgs.writeText "password" "test123"}";
      "user2@localhost".passwordFile = "${pkgs.writeText "password" "test123"}";
      "admin@localhost".passwordFile = "${pkgs.writeText "password" "test123"}";
    };
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

  # Creating Nextcloud users and configure mail adresses
  systemd.services.nextcloud-add-user = {
    script = ''
      export OC_PASS="test123"
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:add --password-from-env user1
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting user1 settings email "user1@localhost"
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:add --password-from-env user2
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting user2 settings email "user2@localhost"
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting admin settings email "admin@localhost"
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "nextcloud";
    };
    after = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  system.stateVersion = "23.05";

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
