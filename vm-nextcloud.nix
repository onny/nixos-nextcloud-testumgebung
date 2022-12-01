{ pkgs, ... }: {

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud25;
    hostName = "localhost";
    config.adminpassFile = "${pkgs.writeText "adminpass" "hunter2"}";
    extraApps = {
      circles = pkgs.fetchNextcloudApp rec {
        url = "https://github.com/nextcloud-releases/circles/releases/download/0.21.4/circles-0.21.4.tar.gz";
        sha256 = "sha256-gkW9jZvXS86ScuM434mUbvQajYKwHVjm9PfTMNgHL/Q=";
      };
      calendar = pkgs.fetchNextcloudApp rec {
        url = "https://github.com/nextcloud-releases/calendar/releases/download/v4.1.0/calendar-v4.1.0.tar.gz";
        sha256 = "sha256-KALFhCNjofFQMntv3vyL0TJxqD/mBkeDpxt8JV4CPAM=";
      };
    };
  };

  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

}
