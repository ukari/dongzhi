FROM alpine AS hoogle-prefetch

WORKDIR /download

RUN apk add --no-cache wget

RUN wget -O input-haskell-stackage-lts.txt https://www.stackage.org/lts/cabal.config

RUN wget -O input-haskell-stackage-nightly.txt https://www.stackage.org/nightly/cabal.config

RUN wget -O input-haskell-platform.txt https://raw.githubusercontent.com/haskell/haskell-platform/master/hptool/src/Releases2015.hs

RUN wget -O input-haskell-cabal.tar.gz https://hackage.haskell.org/packages/index.tar.gz

RUN wget -O input-haskell-hoogle.tar.gz https://hackage.haskell.org/packages/hoogle.tar.gz

CMD ["tail", "-f", "/dev/null"]

FROM base-nix-haskell:latest AS dev

USER dev

WORKDIR /home/dev

ARG GHC_VERSION=9.6.6
ARG STACK_RESOLVER=lts-22.43
ARG HLS_VERSION=2.9.0.1

ENV GHC_VERSION=${GHC_VERSION} \
    STACK_RESOLVER=${STACK_RESOLVER}
    # HLS_VERSION=${HLS_VERSION}

# RUN --mount=type=tmpfs,target=/tmp \
#     curl --proto '=https' --tlsv1.2 -sSf https://mirrors.ustc.edu.cn/ghcup/sh/bootstrap-haskell | \
#     BOOTSTRAP_HASKELL_NONINTERACTIVE=yes \
#     BOOTSTRAP_HASKELL_NO_UPGRADE=yes \
#     # BOOTSTRAP_HASKELL_GHC_VERSION=recommended \
#     # BOOTSTRAP_HASKELL_CABAL_VERSION=recommended \
#     # BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
#     # BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1 \
#     BOOTSTRAP_HASKELL_MINIMAL=1 \
#     BOOTSTRAP_HASKELL_YAML=https://mirrors.ustc.edu.cn/ghcup/ghcup-metadata/ghcup-latest.yaml \
#     #curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh && echo "source /home/dev/.ghcup/env" >> ~/.bashrc
#     sh && \
#     echo "source /home/dev/.ghcup/env" >> ~/.bashrc && \
#     echo 'url-source:' >> ~/.ghcup/config.yaml && \
#     echo '  OwnSource:' >> ~/.ghcup/config.yaml && \
#     echo '    - https://mirrors.ustc.edu.cn/ghcup/ghcup-metadata/ghcup-latest.yaml' >> ~/.ghcup/config.yaml

RUN echo "export PATH=~/.ghcup/bin:$PATH" >> ~/.bashrc

RUN mkdir -p ~/.ghcup &&\
    touch ~/.ghcup/config.yaml && \
    echo 'url-source:' >> ~/.ghcup/config.yaml && \
    echo '  OwnSource:' >> ~/.ghcup/config.yaml && \
    echo '    - https://mirrors.ustc.edu.cn/ghcup/ghcup-metadata/ghcup-latest.yaml' >> ~/.ghcup/config.yaml

SHELL ["/bin/bash", "-c"]

ENV BASH_ENV="~/.bashrc"

# RUN --mount=type=tmpfs,target=/tmp ghcup install cabal latest --set

# RUN --mount=type=tmpfs,target=/tmp ghcup install stack latest ${STACK_VERSION} --set

RUN --mount=type=tmpfs,target=/tmp ghcup install ghc ${GHC_VERSION} --set

RUN --mount=type=tmpfs,target=/tmp ghcup install hls ${HLS_VERSION} --set

RUN ((stack ghc -- --version 2>/dev/null) || true) && \
    stack config --system-ghc set resolver ${STACK_RESOLVER}

RUN mkdir -p ~/download

COPY --from=hoogle-prefetch /download/* ./download

RUN HOOGLE_ROOT=$(stack path --local-hoogle-root) && \
    mkdir -p ${HOOGLE_ROOT} && \
    touch ${HOOGLE_ROOT}/database.hoo && \
    mv ./download/* ${HOOGLE_ROOT} && \
    rm -rf ./download

# RUN --mount=type=tmpfs,target=/tmp stack hoogle -- generate

CMD ["/bin/bash"]
