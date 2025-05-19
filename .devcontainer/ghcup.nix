{
    fetchurl,
    stdenv,
    lib
}:

let
    pname = "ghcup";
    version = "0.1.40.0";
    # installScript = fetchurl {
    #     url = "https://get-ghcup.haskell.org";
    #     sha256 = "13yj52vc3ghjdshshhrp07jpxjdy1rgsmj7sqwn2y8nbdc8and1k";
    # };
    sources = {
        x86_64-linux = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/x86_64-linux-ghcup-${version}";
            sha256 = "181lr8zmba1fm10fvad6hl6xd862xpygfna27g2gb5p77svm5jkh";
        };
        i686-linux = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/i386-linux-ghcup-${version}";
            sha256 = "0h8jfrcbbbc9if1gydpdm53fyqb4sss6cyg6cd0xhcann7p5zfq1";
        };
        armv7l-linux = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/armv7-linux-ghcup-${version}";
            sha256 = "1z77a9i9zqk12jx4s43ypn975v3sn585x9np8dxhpx00fxqzab16";
        };
        aarch64-linux = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/aarch64-linux-ghcup-${version}";
            sha256 = "1ws0x0bmdpd36i88h8x8kvq7yi3aqd7yk009id76vjmq989n9pw6";
        };
        x86_64-freebsd = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/x86_64-portbld-freebsd-ghcup-${version}";
            sha256 = "1b0v5rp6bai24pjsyqh5wgi07kxb1fcdmrqcjkycgwrf9vavg438";
        };
        x86_64-darwin = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/x86_64-apple-darwin-ghcup-${version}";
            sha256 = "02gd2k7mrdarirdki19rxfcbkxdqmwi7gw3b909j0fnpnf5mc7rx";
        };
        aarch64-darwin = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/aarch64-apple-darwin-ghcup-${version}";
            sha256 = "025j5nmshvhzvirhrdmm8i1nkw23ghss8r3r4s8q0d5300l1cnr3";
        };
        x86_64-windows = fetchurl {
            url = "https://downloads.haskell.org/~ghcup/${version}/x86_64-mingw64-ghcup-${version}.exe";
            sha256 = "04l1xi8s1a86ghywcj6iqp60fscwhij5y3fmxasffivfz863xbv5";
        };
    };
    system = stdenv.hostPlatform.system;
    exeExtension = lib.optionalString stdenv.hostPlatform.isWindows ".exe";
    ghcupBinary = sources.${system} or (throw "Unsupport system : ${system}");

in stdenv.mkDerivation {
    inherit pname version;

    src = ghcupBinary;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
        runHook preInstall
        install -Dm755 $src $out/bin/ghcup${exeExtension}
        runHook postInstall
    '';

}