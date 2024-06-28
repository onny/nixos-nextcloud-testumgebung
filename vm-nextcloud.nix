{ pkgs, config, lib, options, ... }: {

  virtualisation = {
    memorySize = 8000;
    cores = 4;
  };

  imports = [
    ./nextcloud-extras.nix
  ];

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard and password policy check from Nextcloud
        # package
        nextcloud29 = super.nextcloud29.overrideAttrs (oldAttrs: rec {
          version = "29.0.3";
          # FIXME
          src = builtins.fetchurl {
            url = "https://download.nextcloud.com/server/releases/nextcloud-${version}.tar.bz2";
            sha256 = "1m3zvcf77mrb7bhhn4hb53ry5f1nqwl5p3sdhkw2f28j9iv6x6d5";
          };
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
    package = pkgs.nextcloud29;
    hostName = "localhost";
    extraApps = with config.services.nextcloud.package.packages.apps; {
     inherit contacts calendar user_oidc;
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
    settings = {
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";
      trusted_domains = [ "10.100.100.1" ];
      "integrity.check.disabled" = true;
      debug = true;
      # Required to allow insecure connection to KeyCloak on localhost
      allow_local_remote_servers = true;
      #apps_paths = [
      #  {
      #    path = "/var/lib/nextcloud/server/apps";
      #    url = "/apps";
      #    writable = false;
      #  }
      #];
    };
  };

  nixos-shell.mounts.extraMounts = {
    "/var/lib/nextcloud/store-apps/cleanup" = {
       target = /home/onny/projects/nixos-nextcloud-testumgebung/cleanup;
       cache = "none";
    };
    "/var/lib/nextcloud/store-apps/files_mindmap" = {
       target = /home/onny/projects/nixos-nextcloud-testumgebung/files_mindmap;
       cache = "none";
    };
    #"/var/lib/nextcloud/server" = {
    #   target = /home/onny/projects/nixos-nextcloud-testumgebung/server;
    #   cache = "none";
    #};
  };

  #services.nginx.virtualHosts."localhost".root = lib.mkForce "/var/lib/nextcloud/server";

  # Setup mail server
  services.stalwart-mail = {
    enable = true;
    # FIXME remove package definition in 24.11
    package = pkgs.stalwart-mail;
    settings = {
      server = {
        hostname = "localhost";
        tls.enable = false;
        listener = {
          "smtp-submission" = {
            bind = [ "[::]:587" ];
            protocol = "smtp";
          };
          "imap" = {
            bind = [ "[::]:143" ];
            protocol = "imap";
          };
        };
      };
      imap.auth.allow-plain-text = true;
      session.auth = {
        mechanisms = "[plain, login]";
        directory = "'in-memory'";
      };
      storage.directory = "in-memory";
      session.rcpt.directory = "'in-memory'";
      queue.outbound.next-hop = "'local'";
      directory."in-memory" = {
        type = "memory";
        principals = [
          {
            class = "individual";
            name = "user1";
            secret = "test123";
            email = [ "user1@localhost" ];
          }
          {
            class = "individual";
            name = "user2";
            secret = "test123";
            email = [ "user2@localhost" ];
          }
          {
            class = "individual";
            name = "admin";
            secret = "test123";
            email = [ "admin@localhost" ];
          }
        ];
      };
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
      user = "admin";
      password = "test123";
    };
  };

  # How to setup https://www.schiessle.org/articles/2023/07/04/nextcloud-and-openid-connect/
  services.keycloak = {
    enable = true;
    settings = {
      hostname = "localhost";
      http-enabled = true;
      http-port = 8081;
      hostname-strict-https = false;
    };
    database.passwordFile = "${pkgs.writeText "dbPassword" ''test123''}";
  };

  system.stateVersion = "24.05";

  environment.systemPackages = with pkgs; [
    litecli
    sqldiff
    unzip
    wget
  ];

  documentation = {
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

}
