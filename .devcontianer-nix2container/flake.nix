{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = { self, nixpkgs, flake-utils, nix2container }: flake-utils.lib.eachDefaultSystem (
      system:
        let 
          pkgs = import nixpkgs {inherit system;};
          nix2containerPkgs = nix2container.packages.x86_64-linux;
          parseTime = with builtins; str: "${substring 0 4 str}-${substring 4 2 str}-${substring 6 2 str}T${substring 8 2 str}:${substring 10 2 str}:${substring 12 2 str}Z";
          dockerImage = nix2containerPkgs.nix2container.buildImage {
            name = "hello-docker";
            tag = "dev";
            created = parseTime self.lastModifiedDate;
            config = {
              entrypoint = ["${pkgs.hello}/bin/hello"];
              env = [ 
                "LANG=C.UTF-8"
                "GOPROXY=https://gocenter.io"
              ];
            };
            # copyToRoot https://github.com/nlewo/nix2container/blob/master/examples/bash.nix
            
          # When we want tools in /, we need to symlink them in order to
          # still have libraries in /nix/store. This behavior differs from
          # dockerTools.buildImage but this allows to avoid having files
          # in both / and /nix/store.
            copyToRoot = [
              (pkgs.buildEnv {
                name = "root";
                paths = with pkgs; [
                  pkgs.bashInteractive
                ];
                pathsToLink = [ "/bin" ];
              })
            ];

            layers = [
              (nix2containerPkgs.nix2container.buildLayer {
                deps = with pkgs; [
                  stack
                  cabal-install
                  haskell-language-server
                ];
              })
            ];
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


