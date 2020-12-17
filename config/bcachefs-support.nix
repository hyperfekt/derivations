{ pkgs, lib, config, ...}:
let
  unstable = import (builtins.fetchTarball "https://github.com/luc65r/nixpkgs/archive/staging.tar.gz") { config = config.nixpkgs.config; };
  kernel = {
    date = "2020-12-16";
    commit = "7f7be490e6a99f2131f0ee044411f51dcbfbcd0c";
    diffhash = "";
    version = "5.10-rc7";
    base = "";
  };
  tools = {
    date = "2020-12-04";
    commit = "db931a4571817d7d61be6bce306f1d42f7cd3398";
    hash = "1zl8lda6ni6rhsmsng6smrcjihy2irjf03h1m7nvkqmkhq44j80s";
  };
  upstreamkernel = "linux_${lib.versions.major kernel.version}_${lib.versions.minor kernel.version}";
in
{
  disabledModules = [ "tasks/filesystems/zfs.nix" ];
  
  imports = [ ./debugkernel.nix ];

  options.security.pam.services = with lib; mkOption {
    type = types.loaOf (types.submodule {
      config.text = mkDefault (mkAfter "session required pam_keyinit.so force revoke");
    });
  };

  config = {
    nix.useSandbox = false;

    nixpkgs.overlays = [ (
      self: super: {
        linux_testing_bcachefs = unstable.linux_testing.override {
	  argsOverride = {
            version = "${kernel.version}.${lib.replaceStrings ["-"] ["."] kernel.date}";
            src = unstable.fetchFromGitHub {
              owner = "koverstreet";
              repo = "bcachefs";
	      rev = kernel.commit;
              sha256 = "15dy181p1w7wpwr9jj8l82s3cfsv8krc7284dw7n4m8my21n3gsg";
            };
          };
          modDirVersionArg = builtins.replaceStrings ["-"] [".0-"] kernel.version;
        /*linux_testing_bcachefs = unstable."${upstreamkernel}".override {
          version = "${kernel.version}.${lib.replaceStrings ["-"] ["."] kernel.date}";
          kernelPatches = unstable."${upstreamkernel}".kernelPatches ++ [(rec {
            name = "bcachefs-${kernel.date}";
            patch = super.fetchurl {
              name = "bcachefs-${kernel.commit}.diff";
              url = "https://github.com/koverstreet/bcachefs/compare/${kernel.base}...${kernel.commit}.diff";
              sha256 = kernel.diffhash;
            };
          })];*/
          dontStrip = true;
          extraConfig = "BCACHEFS_FS m";
        };
        bcachefs-tools = super.bcachefs-tools.overrideAttrs (oldAttrs: rec {
          version = tools.date;
          src = pkgs.fetchFromGitHub {
            owner = "koverstreet";
            repo = "bcachefs-tools";
            rev = tools.commit;
            sha256 = tools.hash;
          };
          meta.broken = false;
          doCheck = false;
          buildInputs = oldAttrs.buildInputs ++ [ self.libudev.dev self.valgrind ];
        });
      }
    ) ];

    boot.supportedFilesystems = [ "bcachefs" ];

    boot.kernelPatches = [
      {
        name = "bcachefs-acl";
        patch = null;
        extraConfig = ''
          BCACHEFS_POSIX_ACL y
        '';
      }
      {
        name = "bcachefs-debug";
        patch = null;
        extraConfig = ''
          BCACHEFS_DEBUG y
        '';
      }
    ];
  };
}

