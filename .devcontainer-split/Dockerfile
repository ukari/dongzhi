FROM base-nix-haskell:latest

ARG STACK_RESOLVER=nightly

ENV STACK_RESOLVER=${STACK_RESOLVER}

# RUN echo "/lib" > /etc/ld.so.conf && \
#     ldconfig

# RUN --mount=type=tmpfs,target=/tmp stack --verbose --resolver ${STACK_RESOLVER} setup && \
#     stack config --system-ghc set install-ghc true --global && \
#     stack config --system-ghc set system-ghc false --global



CMD ["sleep", "infinity"]