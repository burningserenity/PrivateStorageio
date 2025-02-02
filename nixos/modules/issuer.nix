# A NixOS module which can run a Ristretto-based issuer for PrivacyStorage
# ZKAPs.
{ lib, pkgs, config, ... }: let
  pspkgs = pkgs.callPackage ./pspkgs.nix { };
  zkapissuer = pspkgs.callPackage ../pkgs/zkapissuer.nix { };
  cfg = config.services.private-storage-issuer;
in {
  options = {
    services.private-storage-issuer.enable = lib.mkEnableOption "PrivateStorage ZKAP Issuer Service";
    services.private-storage-issuer.package = lib.mkOption {
      default = zkapissuer.components.exes."PaymentServer-exe";
      type = lib.types.package;
      example = lib.literalExample "pkgs.zkapissuer.components.exes.\"PaymentServer-exe\"";
      description = ''
        The package to use for the ZKAP issuer.
      '';
    };
    services.private-storage-issuer.issuer = lib.mkOption {
      default = "Ristretto";
      type = lib.types.str;
      example = lib.literalExample "Trivial";
      description = ''
        The issuer algorithm to use.  Either Trivial for a fake no-crypto
        algorithm or Ristretto for Ristretto-flavored PrivacyPass.
      '';
    };
    services.private-storage-issuer.ristrettoSigningKey = lib.mkOption {
      default = null;
      type = lib.types.str;
      description = ''
        The Ristretto signing key to use.  Required if the issuer is
        ``Ristretto``.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Add a systemd service to run PaymentServer.
    systemd.services.zkapissuer = {
      enable = true;
      description = "ZKAP Issuer";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart =
          let
            # Compute the right command line arguments to pass to it.  The
            # signing key is only supplied when using the Ristretto issuer.
            args =
              if cfg.issuer == "Trivial"
                then "--issuer Trivial"
                else "--issuer Ristretto --signing-key ${cfg.ristrettoSigningKey}";
          in
            "${cfg.package}/bin/PaymentServer-exe ${args}";
        Type = "simple";
        # It really shouldn't ever exit on its own!  If it does, it's a bug
        # we'll have to fix.  Restart it and hope it doesn't happen too much
        # before we can fix whatever the issue is.
        Restart = "always";
      };
    };
  };
}
