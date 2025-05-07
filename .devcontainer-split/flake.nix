{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = { self, nixpkgs, flake-utils, nix2container }: flake-utils.lib.eachDefaultSystem (
      system:
        let 
          pkgs = import nixpkgs {inherit system;};
          uid = 2000;
          gid = 2000;
          # baseImage = pkgs.dockerTools.buildImage {
          #   name = "base";
          #   tag = "latest";

          #   fromImageTag = "latest";

          #   copyToRoot = with pkgs; buildEnv {
          #     name = "base";
          #     paths = [
          #       bashInteractive
          #     ];
          #     pathsToLink = [ "/bin" ];
          #   };
          # };

          # defaultRuntime = with pkgs; [
            #acl
            #attr
            #bashInteractive # bash with ncurses support
            #bzip2
            #coreutils-full
            #cpio
#            curl
            #diffutils
#            findutils
#            gawk
            #stdenv.cc.libc
            #getent
            #getconf
#            gnugrep
            #gnupatch
#            gnused
#            gnutar
            #gzip
#            xz
            #less
            #libcap
#            ncurses # ncurses6
            #netcat
            #config.programs.ssh.package
            #mkpasswd
            #procps
            #su
            #time
            #util-linux
#            which
            #zstd
          # ];

          stackRuntime = with pkgs; [
            cacert # tls cert
            iconv # ldconfig
            gnumake
            gmp # for libgmp.so.10
            gmp4 # for libgmp.so.3
            ncurses # ncurses6
            ncurses5 # for libtinfo.so.5
            findutils # for find
            gnugrep # for grep
            gawk
            gnused
            gnutar
            xz
          ] ++ (with pkgs.llvmPackages_19; [
            bintools
            clang
          ]);

          toolPackages = with pkgs; [
            curl
            strace
            iproute2
            which
            nano
          ];

          devtoolPackages = with pkgs.haskellPackages; [
            fsnotify
            haskell-dap
            ghci-dap
            haskell-debug-adapter
            hlint
            apply-refact
            retrie
            hoogle
            ormolu
          ];

          devcontainerEnvironment = with pkgs; [
            gzip
            (fakeNss.override {
              extraPasswdLines = ["dev:x:${builtins.toString uid}:${builtins.toString gid}:developer:/var/empty:/bin/sh"];
              extraGroupLines = ["dev:x:${builtins.toString gid}:"];
            }) # devcontainer needs root user
            stdenv.cc.cc.lib # libstdc++.so.6 for devcontainer script check requirements
          ];

          packages = with pkgs; [
              bashInteractive
              coreutils-full

              stack
              cabal-install
              haskell-language-server
            ] ++ toolPackages ++ stackRuntime ++ devtoolPackages ++ devcontainerEnvironment;

          # https://github.com/NixOS/nixpkgs/blob/a3f9ad65a0bf298ed5847629a57808b97e6e8077/nixos/modules/programs/nix-ld.nix
          nix-ld-libraries = pkgs.buildEnv {
            name = "ld-library-path";
            pathsToLink = [ "/lib" ];
            paths = map pkgs.lib.getLib packages;
            postBuild = with pkgs; ''
              ln -s ${stdenv.cc.bintools.dynamicLinker} $out/share/nix-ld/lib/ld.so

              mkdir -p $out/etc
              echo /share/nix-ld/lib/ >> $out/etc/ld.so.conf
              echo /lib >> $out/etc/ld.so.conf
              echo $out/share/nix-ld/lib/ >> ./ld.so.conf
              echo $out/lib >> ./ld.so.conf
              ${iconv}/bin/ldconfig -f ./ld.so.conf -C $out/etc/ld.so.cache
              ${iconv}/bin/ldconfig -p -C $out/etc/ld.so.cache > $out/tmplog
            '';
            extraPrefix = "/share/nix-ld";
            ignoreCollisions = true;
          };

          nix-ld-ldso = let 
            libDir = if builtins.elem pkgs.stdenv.system [ "x86_64-linux" "mips64-linux" "powerpc64le-linux" ]
              then "/lib64"
              else "/lib";
            in pkgs.buildEnv {
            name = "nix-ld-ldso";
            pathsToLink = [ ];
            paths = [ ];
            postBuild = with pkgs; ''
              mkdir -p $out/${libDir}
              ln -s ${nix-ld}/libexec/nix-ld $out/${libDir}/"$(basename ${stdenv.cc.bintools.dynamicLinker})"
            '';
          };

          # ldconfig-cache = pkgs.buildEnv {
          #   name = "ldconfig-cache";
          #   pathsToLink = [ ];
          #   paths = [ ];
          #   postBuild = with pkgs; ''
          #     mkdir -p $out/etc
          #     ${iconv}/bin/ldconfig -C $out/etc/ld.so.cache
          #   '';
          # };

          nix-ld-env = pkgs.writeShellApplication {
            name = "nix-ld-env";
            runtimeInputs = with pkgs; [ pkgs.coreutils ];
            text = with pkgs; ''
              prog="$1"
              shift
              progPath=$(command -v "$prog")
              if [ -z "$progPath" ]; then
                echo "Error: program '$prog' not found" >&2
                exit 1
              fi
              exec ${nix-ld}/libexec/nix-ld "$progPath" "$@"
            '';
          };

          env-usr-bin = pkgs.buildEnv {
            name = "env-usr-bin";
            pathsToLink = [ ];
            paths = with pkgs; [
              (lib.getLib coreutils-full)
            ];
            postBuild = with pkgs; ''
              mkdir -p $out/usr/bin
              #ln -s ${coreutils-full}/bin/env $out/usr/bin/env
              ln -s ${nix-ld-env}/bin/nix-ld-env $out/usr/bin/env
            '';
          };

          etc-profile = pkgs.buildEnv {
            name = "env-usr-bin";
            pathsToLink = [ ];
            paths = with pkgs; [ ];
            postBuild = with pkgs; ''
              mkdir -p $out/etc
              touch $out/etc/profile
            '';
          };

          dockerImage = pkgs.dockerTools.streamLayeredImage {
            name = "base-nix-haskell";
            tag = "latest";
            created = "now";
            #fromImage = null;

            contents = [ 
              nix-ld-libraries 
              nix-ld-ldso
              #ldconfig-cache # devcontainer script needs /etc/ld.so.cache
              env-usr-bin # devcontainer script needs /usr/bin/env
              etc-profile # devcontainer needs /etc/profile
            ] ++ packages;


            config = with pkgs; {
              Cmd = [ "/bin/bash" ];
              Env = [ 
                "LANG=C.UTF-8" 
                "NIX_LD=/share/nix-ld/lib/ld.so"
                "NIX_LD_LIBRARY_PATH=/share/nix-ld/lib"
              ];

            };

            # fakeRootCommands = with pkgs; ''
            #     #!${runtimeShell}
            #     echo ${iconv}/bin/ldconfig > /tmplog
            #     ${iconv}/bin/ldconfig -C /etc/ld.so.cache 2> /tmperr
            # '';

            # enableFakechroot = true;
          };
        in 
        {
          packages.x86_64-linux.default = dockerImage;
          packages = {
            test = dockerImage;
          };
        }
      
      );
}


