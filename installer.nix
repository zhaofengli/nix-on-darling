{ pkgs, lib, callPackage, nix, cacert, writeShellScript }:
let
  nix' = nix.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      # The emulated fs doesn't seem to support lchflags well :/
      ./nix-darling.patch
    ];
  });

  nixConf = pkgs.writeText "nix.conf" ''
    sandbox = false
    experimental-features = flakes nix-command
    trusted-users = @wheel
  '';

  nixProfile = pkgs.writeText "nix.sh" ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
  '';

  bootstrapScript = pkgs.writeShellScript "bootstrap-nix" ''
    set -euo pipefail

    echo "Bootstrapping Nix..."

    profile=/nix/var/nix/profiles/default

    ${nix'}/bin/nix-store --load-db < /nix-path-registration
    rm -f /nix-path-registration
    chmod u+rwx,g+rwx,o+rwt /private/tmp
    ${nix'}/bin/nix-env --profile $profile -i ${nix'}
    ${nix'}/bin/nix-env --profile $profile -i ${cacert}

    echo "Run the following command to make Nix work in the current shell:"
    echo ". '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'"

    rm /usr/local/bin/bootstrap-nix
  '';
in callPackage (pkgs.path + "/nixos/lib/make-system-tarball.nix") {
  extraArgs = "--owner=0";

  storeContents = [
    {
      object = nix';
      symlink = "none";
    }
    {
      object = bootstrapScript;
      symlink = "/usr/local/bin/bootstrap-nix";
    }
  ];

  contents = [
    {
      source = nixConf;
      target = "/private/etc/nix/nix.conf";
    }
    {
      source = nixProfile;
      target = "/private/etc/profile.d/nix.sh";
    }
  ];
}
