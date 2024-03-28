{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    optionalString
    escapeShellArg
    types
    concatStringsSep
    mapAttrsToList
    mkIf
    mkOption
    ;

  cfg = config.services.nextcloud;

in {
  options = {
    services.nextcloud = {

      ensureUsers = mkOption {
        default = {};
        description = lib.mdDoc ''
          List of user accounts which get automatically created if they don't
          exist yet. This option does not delete accounts which are not listed
          anymore.
        '';
        example = {
          user1 = {
            passwordFile = /secrets/user1-localhost;
            email = "user1@localhost";
          };
          user2 = {
            passwordFile = /secrets/user2-localhost;
            email = "user2@localhost";
          };
        };
        type = types.attrsOf (types.submodule {
          options = {
            passwordFile = mkOption {
              type = types.path;
              example = "/path/to/file";
              default = null;
              description = lib.mdDoc ''
                Specifies the path to a file containing the
                clear text password for the user.
              '';
            };
            email = mkOption {
              type = types.str;
              example = "user1@localhost";
              default = null;
            };
          };
        });
      };

    };
  };

  config = mkIf cfg.enable {

    systemd.services.nextcloud-ensure-users = {
      enable = true;
      script = ''
        ${optionalString (cfg.ensureUsers != {}) ''
          ${concatStringsSep "\n" (mapAttrsToList (name: cfg: ''
            if ${config.services.nextcloud.occ}/bin/nextcloud-occ user:info "${name}" | grep "user not found"; then
              export OC_PASS="$(cat ${escapeShellArg cfg.passwordFile})"
              ${config.services.nextcloud.occ}/bin/nextcloud-occ user:add --password-from-env "${name}"
            fi
            if ! ${config.services.nextcloud.occ}/bin/nextcloud-occ user:info "${name}" | grep "user not found"; then
              ${optionalString (cfg.email != null) ''
                ${config.services.nextcloud.occ}/bin/nextcloud-occ user:setting "${name}" settings email "${cfg.email}"
              ''}
            fi
          '') cfg.ensureUsers)}
        ''}
      '';
      wantedBy = [ "multi-user.target" ];
      after = ["nextcloud-setup.service"];
    };

  };
}
