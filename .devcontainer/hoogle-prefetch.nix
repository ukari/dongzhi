{
    fetchurl,
    stdenv
}:

let
    pname = "hoogle-prefetch";
    version = "20240514";
    input-haskell-stackage-lts = fetchurl {
        url = "https://www.stackage.org/lts/cabal.config";
        sha256 = "1xl4wxk0qdkr256bf2fibhmwh2750n6pqgird8fl55np0vr2iyfs";
    };
    input-haskell-stackage-nightly = fetchurl {
        url = "https://www.stackage.org/nightly/cabal.config";
        sha256 = "0yn8gx3q6v4p6yi48l072j4qbjmc6kv4ndib47l4rf6860z4qki7";
    };
    input-haskell-platform = fetchurl {
        url = "https://raw.githubusercontent.com/haskell/haskell-platform/master/hptool/src/Releases2015.hs";
        sha256 = "1dfj527q7jxr6w4qda3ha82x0i9cd3rcvym0iy2slbdkgpvvj4pq";
    };
    input-haskell-cabal = fetchurl {
        url = "https://hackage.haskell.org/packages/index.tar.gz";
        sha256 = "1qygilrb69kpqwwzhd2nirkprkkigh3p5b51v5j2smrl96xrd8nk";
    };
    input-haskell-hoogle = fetchurl {
        url = "https://hackage.haskell.org/packages/hoogle.tar.gz";
        sha256 = "12aqpxnpwb5p7l1lzfg78nbjn8rjzkfycir1facgrjrgprz4bnbj";
    };
in stdenv.mkDerivation {

    inherit pname;

    inherit version;

    src = null;

    dontUnpack = true;

    installPhase = ''
        mkdir -p $out/cache

        ln -s ${input-haskell-stackage-lts} $out/cache/input-haskell-stackage-lts.txt

        ln -s ${input-haskell-stackage-nightly} $out/cache/input-haskell-stackage-nightly.txt

        ln -s ${input-haskell-platform} $out/cache/input-haskell-platform.txt

        ln -s ${input-haskell-cabal} $out/cache/input-haskell-cabal.tar.gz

        ln -s ${input-haskell-hoogle} $out/cache/input-haskell-hoogle.tar.gz
    '';

}