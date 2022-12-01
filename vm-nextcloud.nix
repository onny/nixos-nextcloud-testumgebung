{ pkgs, ... }: {

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud25;
    hostName = "localhost";
    config.adminpassFile = "${pkgs.writeText "adminpass" "hunter2"}";
    extraApps = {
      circles = pkgs.fetchNextcloudApp rec {
        url = "https://github.com/nextcloud-releases/circles/releases/download/0.21.4/circles-0.21.4.tar.gz";
        sha256 = "sha256-sQUsYC3cco6fj9pF2l1NrCEhA3KJoOvJRhXvBlVplll=";
      };
      calendar = pkgs.fetchNextcloudApp rec {
        url = "https://github.com/nextcloud-releases/calendar/releases/download/v4.1.0/calendar-v4.1.0.tar.gz";
        sha256 = "sha256-eTc51pkg3OdHJB7X4/hD39Ce+9vKzw1nlJ7BhPOzlll=";
      };
    };
  };

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
