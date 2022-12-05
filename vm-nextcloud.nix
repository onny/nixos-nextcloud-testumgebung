{ pkgs, config, ... }: {

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard from Nextcloud package
        nextcloud25 = super.nextcloud25.overrideAttrs (oldAttrs: rec {
          installPhase = oldAttrs.installPhase + ''
            rm -r $out/apps/firstrunwizard
            rm -r $out/apps/password_policy
          '';
        });
      })
    ];
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud25;
    hostName = "localhost";
    config = {
      adminuser = "admin";
      adminpassFile = "${pkgs.writeText "adminpass" "test123"}";
    };
    extraApps = {
      circles = pkgs.fetchNextcloudApp rec {
        url = "https://github.com/nextcloud-releases/circles/releases/download/0.21.4/circles-0.21.4.tar.gz";
        sha256 = "sha256-gkW9jZvXS86ScuM434mUbvQajYKwHVjm9PfTMNgHL/Q=";
      };
      calendar = pkgs.fetchNextcloudApp rec {
        url = "https://github.com/nextcloud-releases/calendar/releases/download/v4.1.0/calendar-v4.1.0.tar.gz";
        sha256 = "sha256-KALFhCNjofFQMntv3vyL0TJxqD/mBkeDpxt8JV4CPAM=";
      };
      mail = pkgs.nextcloud25Packages.apps.mail;
    };
  };

  services.maddy = {
    enable = true;
    hostname = "localhost";
    primaryDomain = "localhost";
  };

  programs.msmtp = {
    enable = true;
    accounts.default = {
      host = "localhost";
      tls = false;
      port = 587;
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
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "nextcloud";
    };
    after = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
