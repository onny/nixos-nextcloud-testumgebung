{ pkgs, ... }: {

  nixpkgs = {
    overlays = [
      (self: super: {
        # Remove first run wizard from Nextcloud package
        nextcloud25 = super.nextcloud25.overrideAttrs (oldAttrs: rec {
          installPhase = oldAttrs.installPhase + ''
            rm -r $out/apps/firstrunwizard
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

  systemd.services.maddy-accounts = {
    script = ''
      set -eu
      ${pkgs.coreutils}/bin/echo "Creating mail users and inboxes"
      ${pkgs.maddy}/bin/maddyctl creds create --password test123 user1@localhost
      ${pkgs.maddy}/bin/maddyctl imap-acct create user1@localhost
      ${pkgs.maddy}/bin/maddyctl creds create --password test123 user2@localhost
      ${pkgs.maddy}/bin/maddyctl imap-acct create user2@localhost
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "maddy";
    };
    after = [ "maddy.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
