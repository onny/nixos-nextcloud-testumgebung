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
     inherit contacts calendar user_oidc hmr_enabler;
    };
    extraAppsEnable = true;
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "adminpass" "test123"}";
    };
    ensureUsers = {
      admin = {
        email = "admin@localhost";
        passwordFile = "${pkgs.writeText "password" "test123"}";
      };
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
    extraOCCCommands = ''
      ${config.services.nextcloud.occ}/bin/nextcloud-occ app:enable cleanup
      ${config.services.nextcloud.occ}/bin/nextcloud-occ user_oidc:provider Keycloak \
        --clientid="nextcloud" \
        --clientsecret="4KoWtOWtg8xpRdAoorNan4PdfFMATo91" \
        --discoveryuri="http://localhost:8081/realms/OIDCDemo/.well-known/openid-configuration" \
        --unique-uid=0 \
        --mapping-uid=preferred_username \
        --no-interaction
    '';
    settings = {
      log_type = "file";
      loglevel = 1;
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
    "/var/lib/nextcloud/store-apps/files_mindmap2" = {
       target = /home/onny/projects/nixos-nextcloud-testumgebung/files_mindmap2;
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
      tracer.stdout = {
        type = "stdout";
        level = "debug";
        enable = true;
        ansi = true;
      };
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
  # FIXME auto setup realm https://github.com/NixOS/nixpkgs/pull/273833
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
    tmux
  ];

  services.getty.autologinUser = "root";

  documentation = {
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

}
