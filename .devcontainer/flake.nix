{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = { self, nixpkgs, flake-utils, nix2container }: flake-utils.lib.eachDefaultSystem (
      system:
        let 
            pkgs = import nixpkgs {
                inherit system;
                overlays = [
                    (final: prev: {
                        ghcup = prev.callPackage ./ghcup.nix {};
                    }) 
                ];
            };
            uid = 2000;
            gid = 2000;
            user = "dev";

            glibcUseSystemLdSoCache = with pkgs; glibc.overrideAttrs (oldAttrs: {
                patches = lib.filter (p: !(builtins.baseNameOf p == "dont-use-system-ld-so-cache.patch")) oldAttrs.patches;
            });

            stackRuntime = with pkgs; [
                cacert # tls cert
                glibcUseSystemLdSoCache.bin # ldconfig
                gnumake
                gmp # for libgmp.so.10
                #gmp4 # for libgmp.so.3
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

            haskellLanguageServerRuntime = with pkgs; [
                libz # for libz.so.1
            ];

            toolPackages = with pkgs; [
                curl
                strace
                iproute2
                which
                nano
            ];

            devtoolPackages = map (pkg: pkgs.haskell.lib.justStaticExecutables pkg) (with pkgs.haskellPackages; [
                # fsnotify
                # haskell-dap
                # ghci-dap
                # haskell-debug-adapter
                # hlint
                # apply-refact
                # retrie
                hoogle
                # ormolu
            ]);

            devcontainerEnvironment = with pkgs; [
                gzip
                (fakeNss.override {
                    extraPasswdLines = ["${user}:x:${builtins.toString uid}:${builtins.toString gid}:developer:/home/${user}:/bin/sh"];
                    extraGroupLines = ["${user}:x:${builtins.toString gid}:"];
                }) # devcontainer needs root user
                stdenv.cc.cc.lib # libstdc++.so.6 for devcontainer script check requirements
                (runCommand "create-user-home" {} ''
                    mkdir -p $out/home/${user}
                '')
            ];

            std-cacert-install = with pkgs; buildEnv { # https://github.com/NixOS/nixpkgs/blob/5938a720cc08975912238e899be874463d3ad0ef/nixos/modules/security/ca.nix
                name = "std-cacert-install";
                pathsToLink = [ ];
                paths = [ cacert ];
                postBuild = ''
                    mkdir -p $out/etc/ssl/certs
                    ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-certificates.crt
                '';
                extraPrefix = "/etc/ssl/certs";
            };

            commonRuntime = with pkgs; [
                git
            ];

            globalStackConfigFile = ''
                # stackage
                setup-info-locations: ["https://mirrors.tuna.tsinghua.edu.cn/stackage/stack-setup.yaml"]
                urls:
                    latest-snapshot: https://mirrors.tuna.tsinghua.edu.cn/stackage/snapshots.json

                snapshot-location-base: https://mirrors.tuna.tsinghua.edu.cn/stackage/stackage-snapshots/

                #ghc-options:
                #  "$everything": -haddock

                # hackage
                package-index:
                    download-prefix: https://mirrors.tuna.tsinghua.edu.cn/hackage/
                    hackage-security:
                        keyids:
                            - 0a5c7ea47cd1b15f01f5f51a33adda7e655bc0f0b0615baa8e271f4c3351e21d
                            - 1ea9ba32c526d1cc91ab5e5bd364ec5e9e8cb67179a471872f6e26f0ae773d42
                            - 280b10153a522681163658cb49f632cde3f38d768b736ddbc901d99a1a772833
                            - 2a96b1889dc221c17296fcc2bb34b908ca9734376f0f361660200935916ef201
                            - 2c6c3627bd6c982990239487f1abd02e08a02e6cf16edb105a8012d444d870c3
                            - 51f0161b906011b52c6613376b1ae937670da69322113a246a09f807c62f6921
                            - 772e9f4c7db33d251d5c6e357199c819e569d130857dc225549b40845ff0890d
                            - aa315286e6ad281ad61182235533c41e806e5a787e0b6d1e7eef3f09d137d2e9
                            - fe331502606802feac15e514d9b9ea83fee8b6ffef71335479a2e68d84adc6b0
                        key-threshold: 3 # number of keys required
                        # ignore expiration date, see https://github.com/commercialhaskell/stack/pull/4614
                        ignore-expiry: no


                # stack ghc config
                system-ghc: true
                install-ghc: false

            '';

            globalStackConfigHintFile = ''
                https://mirrors.tuna.tsinghua.edu.cn/github-raw/fpco/stackage-content/master/stack/global-hints.yaml
            '';

            writeFile = {content, destination, isOverwrite ? true, mode ? "644"} : with pkgs; buildEnv {
                name = "write-file";
                pathsToLink = [ ];
                paths = [];
                postBuild = let
                    directory = dirOf destination;
                in ''
                    mkdir -p $out${directory}
                    if [ "${builtins.toString isOverwrite}" = "true" ]; then
                        cat <<'EOF' > $out${destination}
                    ${content}
                    EOF
                    else
                        cat <<'EOF' >> $out${destination}
                    ${content}
                    EOF
                    fi
                    chmod ${mode} $out${destination}
                '';
            };

            global-stack-config = map writeFile [
                ({
                    content = globalStackConfigFile;
                    destination = "/home/${user}/.stack/config.yaml";
                    isOverwrite = false;
                })
                ({
                    content = globalStackConfigHintFile;
                    destination = "/home/${user}/.stack/pantry/global-hints-cache.yaml";
                    isOverwrite = false;
                })
            ];

            osReleaseFile = with pkgs; writeTextDir "/etc/os-release" ''
                ID=nix
            '';

            os-release = with pkgs; buildEnv {
                name = "os-release";
                pathsToLink = [ "/etc" ];
                paths = [ osReleaseFile ];
            };

            packages = with pkgs; [
                bashInteractive
                coreutils-full

                stack
                cabal-install
                ghcup
                # (haskell-language-server.override {
                #   dynamic = false;
                #   supportedGhcVersions = [ ];
                # })
            ]
            ++ toolPackages
            ++ stackRuntime
            ++ haskellLanguageServerRuntime
            ++ devtoolPackages
            ++ devcontainerEnvironment
            ++ commonRuntime;

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
                    ${glibcUseSystemLdSoCache.bin}/bin/ldconfig -f ./ld.so.conf -C $out/etc/ld.so.cache
                    ${glibcUseSystemLdSoCache.bin}/bin/ldconfig -p -C $out/etc/ld.so.cache > $out/tmplog
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

            ghcup-profile = let
                user-profile = 
                    ''
                        export PATH=~/.ghcup/bin:$PATH
                    '';
            in
            with pkgs; buildEnv {
                name = "ghcup-profile";
                pathsToLink = [ ];
                paths = [ ];
                postBuild = with pkgs; ''
                    mkdir -p $out/home/${user}
                    cat > $out/home/${user}/.profile << 'EOF'
                    ${user-profile}
                    EOF
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
                    env-usr-bin # devcontainer script needs /usr/bin/env
                    #etc-profile # devcontainer needs /etc/profile
                    ghcup-profile
                    std-cacert-install
                    os-release
                ] ++ global-stack-config ++ packages;

                fakeRootCommands = ''
                  chown -R ${builtins.toString uid}:${builtins.toString gid} /home/${user}
                  chmod 755 /home/${user}
                '';

                enableFakechroot = true;

                config = with pkgs; {
                    Cmd = [ 
                        "/bin/bash"
                    ];
                    Env = [ 
                        "LANG=C.UTF-8" 
                        "NIX_LD=/share/nix-ld/lib/ld.so"
                        "NIX_LD_LIBRARY_PATH=/share/nix-ld/lib"
                    ];
                };
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


