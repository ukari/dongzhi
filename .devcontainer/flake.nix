{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (
      system:
        let 
            pkgs = import nixpkgs {
                inherit system;
                overlays = [
                    (final: prev: {
                        ghcup = prev.callPackage ./ghcup.nix {};
                        hoogle-prefetch = prev.callPackage ./hoogle-prefetch.nix {};
                    }) 
                ];
            };
            uid = 2000;
            gid = 2000;
            user = "dev";
            group = user;

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
                unixtools.procps
                psmisc
            ];

            phoityneVscodeDependencies = with pkgs.haskellPackages; [
                #haskell-dap, manage by stack
                #ghci-dap, manage by stack
                haskell-debug-adapter
            ];

            devtoolPackages = map (pkg: pkgs.haskell.lib.justStaticExecutables pkg) (
                (with pkgs.haskellPackages; [
                # fsnotify
                # ghci-dap
                # hlint
                # apply-refact
                # retrie
                hoogle
                # ormolu
                ])
                ++ phoityneVscodeDependencies
            );

            devcontainerEnvironment = with pkgs; [
                gzip
                (fakeNss.override {
                    extraPasswdLines = ["${user}:x:${builtins.toString uid}:${builtins.toString gid}:developer:/home/${user}:/bin/sh"];
                    extraGroupLines = ["${group}:x:${builtins.toString gid}:"];
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


            osReleaseFile = ''
                ID=nix
            '';

            globalStackConfigFile = ''
                # stackage
                setup-info-locations:
                    - http://mirrors.ustc.edu.cn/stackage/stack-setup.yaml
                urls:
                    latest-snapshot: http://mirrors.ustc.edu.cn/stackage/snapshots.json
                snapshot-location-base: http://mirrors.ustc.edu.cn/stackage/stackage-snapshots/
                global-hints-location:
                    url: https://mirrors.ustc.edu.cn/stackage/stackage-content/stack/global-hints.yaml

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

            stackUserProfile = ''
                export PATH=~/.local/bin:$PATH
            '';

            ghcupUserProfile = ''
                export PATH=~/.ghcup/bin:$PATH
            '';

            ghcupConfigFile = ''
                url-source:
                  OwnSource:
                    - https://mirrors.ustc.edu.cn/ghcup/ghcup-metadata/ghcup-latest.yaml
            '';

            makeFile = {content, destination, isOverwrite ? true, mode ? "644", dirMode ? "755", owner ? "root", group ? "root"} : with pkgs; let
                directory = dirOf destination;
                derivation = runCommand "write-file" {}''
                    mkdir -p $out${directory}
                    cat <<'EOF' > $out${destination}
                    ${content}
                    EOF
                '';
            in ({
                    inherit isOverwrite;
                    inherit mode;
                    inherit dirMode;
                    inherit owner;
                    inherit group;
                    path = derivation;
                });

            writeInstallPathScript = name : metas : with pkgs; let 
                makeScript = { path, isOverwrite ? true, mode ? "644", dirMode ? "755", owner ? "root", group ? "root" } : ''
                    export base=${path} dest_base=/
                    cd $base
                    find ./ -type f -exec sh -c -- '
                        export target=$0
                        export dir=$(dirname $target)
                        cd $dest_base
                        if [ ! -d "$dir" ]; then
                          install -d -m ${dirMode} -o ${owner} -g ${group} $dir
                        fi
                        cd $dir
                        if [ "${builtins.toString isOverwrite}" = "true" ]; then
                          install -m ${mode} -o ${owner} -g ${group} $base/$target $dest_base/$target
                        else
                          cat $base/$target >> $dest_base/$target
                          chown ${owner}:${group} $dest_base/$target
                          chmod ${mode} $dest_base/$target
                        fi
                    ' {} \;
                '';
                scripts = map makeScript metas;
                script = ''
                    set -e
                    set -u

                    ${lib.strings.concatMapStrings lib.id scripts}
                '';
            in writeShellScript name script;
            
            init-config = with pkgs; let
            
                metas = map makeFile [
                    ({
                        mode = "755";
                        content = osReleaseFile;
                        destination = "/etc/os-release";
                    })
                    ({
                        content = globalStackConfigFile;
                        destination = "/home/${user}/.stack/config.yaml";
                        owner = "${user}";
                        group = "${group}";
                    })
                    ({
                        content = stackUserProfile;
                        destination = "/home/${user}/.profile";
                        isOverwrite = false;
                        owner = "${user}";
                        group = "${group}";
                    })
                    ({
                        content = ghcupUserProfile;
                        destination = "/home/${user}/.profile";
                        isOverwrite = false;
                        owner = "${user}";
                        group = "${group}";
                    })
                    ({
                        content = ghcupConfigFile;
                        destination = "/home/${user}/.ghcup/config.yaml";
                        owner = "${user}";
                        group = "${group}";
                    })
                ];

            in writeInstallPathScript "init-config" metas;

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

            hoogle-cache = with pkgs; buildEnv {
                name = "hoogle-cache";
                pathsToLink = [ "/cache" ];
                paths = [ hoogle-prefetch ];
            };

            hoogle-prefetch-image = pkgs.dockerTools.streamLayeredImage {
                name = "hoogle-prefetch";
                tag = "latest";
                created = "now";

                contents = [ 
                    hoogle-cache
                ];
            };

            base-nix-haskell-image = pkgs.dockerTools.streamLayeredImage {
                name = "base-nix-haskell";
                tag = "latest";
                created = "now";
                #fromImage = null;

                contents = [ 
                    nix-ld-libraries
                    nix-ld-ldso
                    env-usr-bin # devcontainer script needs /usr/bin/env
                    std-cacert-install
                ] ++ packages;

                fakeRootCommands = ''
                  chown -R ${builtins.toString uid}:${builtins.toString gid} /home/${user}
                  chmod 755 /home/${user}
                  ${init-config}
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
            packages.x86_64-linux.default = base-nix-haskell-image;
            packages = {
                hoogle-prefetch = hoogle-prefetch-image;
                base-nix-haskell = base-nix-haskell-image;
            };
        }
    );
}


