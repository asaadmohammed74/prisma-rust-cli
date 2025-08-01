{
  pkgs,
  stdenv,
  fetchurl,
  lib,
  prisma-cli-hash,
  prisma-cli-version,
  prisma-engines-commit,
  query-engine-hash,
  migration-engine-hash,
  introspection-engine-hash,
  prisma-fmt-hash,
  binaryTargetBySystem ? {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
  },
}:
let
  binaryTarget = binaryTargetBySystem.${pkgs.system};
  operatingSystemSSL = "debian-openssl-3.0.x";
in
rec {
  package = stdenv.mkDerivation {
    name = "prisma-cli-bin";

    srcs = [
      (fetchurl {
        url = "https://prisma-photongo.s3-eu-west-1.amazonaws.com/prisma-cli-${prisma-cli-version}-${binaryTarget}.gz";
        hash = prisma-cli-hash;
      })
      (fetchurl {
        url = "https://binaries.prisma.sh/all_commits/${prisma-engines-commit}/${operatingSystemSSL}/query-engine.gz";
        hash = query-engine-hash;
      })
      (fetchurl {
        url = "https://binaries.prisma.sh/all_commits/${prisma-engines-commit}/${operatingSystemSSL}/migration-engine.gz";
        hash = migration-engine-hash;
      })
      (fetchurl {
        url = "https://binaries.prisma.sh/all_commits/${prisma-engines-commit}/${operatingSystemSSL}/introspection-engine.gz";
        hash = introspection-engine-hash;
      })
      (fetchurl {
        url = "https://binaries.prisma.sh/all_commits/${prisma-engines-commit}/${operatingSystemSSL}/prisma-fmt.gz";
        hash = prisma-fmt-hash;
      })
    ];

    dontStrip = true;

    unpackPhase = ''
      for src in $srcs; do
        gunzip -c $src > $(stripHash $(basename $src .gz))
      done
    '';

    buildPhase = ":";

    installPhase = ''
      mkdir -p $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}

      cp prisma-cli-${prisma-cli-version}-${binaryTarget} $out/prisma/binaries/cli/${prisma-cli-version}/prisma-cli-${binaryTarget}
      cp query-engine $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-query-engine-${operatingSystemSSL}
      cp migration-engine $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-migration-engine-${operatingSystemSSL}
      cp introspection-engine $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-introspection-engine-${operatingSystemSSL}
      cp prisma-fmt $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-prisma-fmt-${operatingSystemSSL}

      chmod +x $out/prisma/binaries/cli/${prisma-cli-version}/prisma-cli-${binaryTarget}
      chmod +x $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-query-engine-${operatingSystemSSL}
      chmod +x $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-migration-engine-${operatingSystemSSL}
      chmod +x $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-introspection-engine-${operatingSystemSSL}
      chmod +x $out/prisma/binaries/cli/${prisma-cli-version}/${prisma-engines-commit}/prisma-prisma-fmt-${operatingSystemSSL}
    '';

    # now is a node program packaged using zeit/pkg.
    # thus, it contains hardcoded offsets.
    # patchelf shifts these locations when it expands headers.

    preFixup =
      let
        libPath = lib.makeLibraryPath [ stdenv.cc.cc ];
      in
      ''
        export PRISMA_CLI_BIN="$out/prisma/binaries/cli/${prisma-cli-version}/prisma-cli-${binaryTarget}"

        # prisma-cli is a binary packaged with pkg, autoPatchelf doesn't work.
        # We need to fix it manually.
        # https://github.com/brendan-hall/nixpkgs/blob/e3b313bb59f49f10970205aafd44878d35da07e7/pkgs/development/web/now-cli/default.nix

        orig_size=$(stat --printf=%s $PRISMA_CLI_BIN)

        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $PRISMA_CLI_BIN
        patchelf --set-rpath ${libPath} $PRISMA_CLI_BIN
        chmod +x $PRISMA_CLI_BIN

        new_size=$(stat --printf=%s $PRISMA_CLI_BIN)

        ###### zeit-pkg fixing starts here.
        # we're replacing plaintext js code that looks like
        # PAYLOAD_POSITION = '1234                  ' | 0
        # [...]
        # PRELUDE_POSITION = '1234                  ' | 0
        # ^-----20-chars-----^^------22-chars------^
        # ^-- grep points here
        #
        # var_* are as described above
        # shift_by seems to be safe so long as all patchelf adjustments occur
        # before any locations pointed to by hardcoded offsets

        var_skip=20
        var_select=22
        shift_by=$(expr $new_size - $orig_size)

        echo "orig_size: $orig_size"
        echo "new_size: $new_size"
        echo "shift_by: $shift_by"

        function fix_offset {
            # $1 = name of variable to adjust
            location=$(grep -obUam1 "$1" $PRISMA_CLI_BIN | cut -d: -f1)
            location=$(expr $location + $var_skip)

            value=$(dd if=$PRISMA_CLI_BIN iflag=count_bytes,skip_bytes skip=$location bs=1 count=$var_select status=none)
            value=$(expr $shift_by + $value)

            echo -n $value | dd of=$PRISMA_CLI_BIN bs=1 seek=$location conv=notrunc
        }

        fix_offset PAYLOAD_POSITION
        fix_offset PRELUDE_POSITION
      '';
  };

  shellHook = ''
    export PRISMA_GLOBAL_CACHE_DIR="${package}"
  '';
}
