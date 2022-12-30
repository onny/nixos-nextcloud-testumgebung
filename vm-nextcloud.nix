{ pkgs, config, lib, options, ... }:{

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard and password policy check from Nextcloud
        # package
        nextcloud25 = super.nextcloud25.overrideAttrs (oldAttrs: rec {
          installPhase = oldAttrs.installPhase + ''
            rm -r $out/apps/firstrunwizard
            rm -r $out/apps/password_policy
          '';
        });
      })
    ];
  };

  # Setup Nextcloud including apps
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud25;
    hostName = "localhost";
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "adminpass" "test123"}";
    };
    extraOptions = {
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";
      debug = true;
      trusted_domains = [ "10.100.100.1" ];
    };
  };
  # Mount our local development app repository into the VM
  nixos-shell.mounts.extraMounts = {
    "/var/lib/nextcloud/store-apps/calendar" = {
      target = /home/onny/projects/calendar;
      cache = "none";
    };
    "/var/lib/nextcloud/server" = {
      target = /home/onny/projects/server;
      cache = "none";
    };
  };
  services.nginx.virtualHosts."localhost".root = lib.mkForce "/var/lib/nextcloud/server";

  # Setup mail server
  services.maddy = {
    enable = true;
    hostname = "localhost";
    primaryDomain = "localhost";
    # Disable any sender validation checks
    config = lib.concatStrings (
      builtins.match "(.*)authorize_sender.*identity\n[ ]+\}(.*)" options.services.maddy.config.default
    );
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
  systemd.services.maddy-accounts = {
    script = ''
      ${pkgs.maddy}/bin/maddyctl creds create --password test123 user1@localhost
      ${pkgs.maddy}/bin/maddyctl imap-acct create user1@localhost
      ${pkgs.maddy}/bin/maddyctl creds create --password test123 user2@localhost
      ${pkgs.maddy}/bin/maddyctl imap-acct create user2@localhost
      ${pkgs.maddy}/bin/maddyctl creds create --password test123 admin@localhost
      ${pkgs.maddy}/bin/maddyctl imap-acct create admin@localhost
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
      ln -fs /var/lib/nextcloud/config /var/lib/nextcloud/server/config
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "nextcloud";
    };
    after = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  system.stateVersion = "21.11";

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
