{ pkgs, config, lib, options, ... }: {

  virtualisation = {
    memorySize = 8000;
    cores = 4;
  };

  # FIXME
  # is it possible to extend existing module with additional options using flake?
  disabledModules = [
    "services/web-apps/nextcloud.nix"
  ];
  imports = [
    "${fetchTarball "https://github.com/onny/nixpkgs/archive/nextcloud-ensureusers.tar.gz"}/nixos/modules/services/web-apps/nextcloud.nix"
  ];

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard and password policy check from Nextcloud
        # package
        nextcloud28 = super.nextcloud28.overrideAttrs (oldAttrs: rec {
          #patches = [];
          #src = ./server;
          installPhase = oldAttrs.installPhase + ''
            mkdir -p $out/
            cp -R . $out/
            rm -r $out/apps/firstrunwizard
            rm -r $out/apps/password_policy
          '';
          dontBuild = true;
        });
      })
    ];
  };

  # Setup Nextcloud including apps
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud28;
    hostName = "localhost";
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit contacts calendar;
      # FIXME
      # enable hmr when debug flag is enabled
      hmr_enabler = pkgs.php.buildComposerProject (finalAttrs: {
        pname = "hmr_enabler";
        version = "1.0.0";
        src = pkgs.fetchFromGitHub {
          owner = "nextcloud";
          repo = "hmr_enabler";
          rev = "b8d3ad290bfa6fe407280587181a5167d71a2617";
          hash = "sha256-yXFby5zlDiPdrw6HchmBoUdu9Zjfgp/bSu0G/isRpKg=";
        };
        composerNoDev = false;
        vendorHash = "sha256-PCWWu/SqTUGnZXUnXyL8c72p8L14ZUqIxoa5i49XPH4=";
        postInstall = ''
          cp -r $out/share/php/hmr_enabler/* $out/
          rm -r $out/share
        '';
      });
    };
    extraAppsEnable = true;
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "adminpass" "test123"}";
    };
    ensureUsers = {
      user1 = {
        email = "user1@localhost";
        passwordFile = "${pkgs.writeText "password" "test123"}";
      };
      user2 = {
        email = "user2@localhost";
        passwordFile = "${pkgs.writeText "password" "test123"}";
      };
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
    appstoreEnable = true;
    configureRedis = true;
    extraOptions = {
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";
      trusted_domains = [ "10.100.100.1" ];
      "integrity.check.disabled" = true;
      debug = true;
    };
  };

  nixos-shell.mounts.extraMounts = {
    "/var/lib/nextcloud/store-apps/cleanup" = {
       target = /home/onny/projects/nixos-nextcloud-testumgebung/cleanup;
       cache = "none";
    };
  };

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

  #system.fsPackages = [ pkgs.bindfs ];

  system.stateVersion = "23.11";

  documentation = {
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

}
