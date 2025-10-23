# syntax=docker/dockerfile:1

# Multi-stage build producing:
# - firecore (from streamingfast/firehose-core)
# - chain poller binary (default: firepersistence) from persistenceOne/firehose-cosmos

ARG FIRECORE_REPO=https://github.com/streamingfast/firehose-core.git
ARG FIRECORE_REF=v1.11.1
ARG FIRECHAIN_REPO=https://github.com/persistenceOne/firehose-cosmos.git
ARG FIRECHAIN_REF=betterclever/persistence-support
ARG CHAIN_BINARY_NAME=firepersistence

FROM golang:1.24 AS firecore_builder

ARG FIRECORE_REPO
ARG FIRECORE_REF

WORKDIR /src/firecore
RUN git clone --depth=1 -b ${FIRECORE_REF} ${FIRECORE_REPO} . \
    && if [ -f go.mod ]; then go mod download; fi

# Build firecore binary
ENV GOTOOLCHAIN=auto
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates build-essential clang pkg-config \
    && rm -rf /var/lib/apt/lists/*
RUN CGO_ENABLED=1 go build -o /out/firecore ./cmd/firecore


FROM golang:1.24 AS firechain_builder

ARG FIRECHAIN_REPO
ARG FIRECHAIN_REF
ARG CHAIN_BINARY_NAME

WORKDIR /src/firechain
RUN git clone --depth=1 -b ${FIRECHAIN_REF} ${FIRECHAIN_REPO} . \
    && if [ -f go.mod ]; then go mod download; fi

ENV GOTOOLCHAIN=auto
RUN set -e; \
    mkdir -p /out; \
    found=""; \
    for name in "${CHAIN_BINARY_NAME}" firepersistence firecosmos fireinjective firemantra; do \
      for path in "./${name}" "./cmd/${name}"; do \
        if [ -d "$path" ]; then \
          echo "Building $name from $path"; \
          (cd "$path" && CGO_ENABLED=0 go build -o "/out/${name}"); \
          found="$name"; \
          break; \
        fi; \
      done; \
      if [ -n "$found" ]; then break; fi; \
    done; \
    if [ -z "$found" ]; then \
      echo "Could not locate chain binary source dir (tried ${CHAIN_BINARY_NAME}, firepersistence, firecosmos, fireinjective, firemantra)"; \
      find . -maxdepth 3 -type d -print; \
      exit 1; \
    fi; \
    # Ensure default name is firepersistence inside image
    if [ "$found" != "firepersistence" ]; then \
      cp "/out/$found" "/out/firepersistence"; \
    fi


FROM ubuntu:24.04 AS runtime

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates bash curl jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=firecore_builder /out/firecore /usr/local/bin/firecore
COPY --from=firechain_builder /out/ /usr/local/bin/

ENV PATH="/usr/local/bin:${PATH}"

# Data directory used by firecore --data-dir
RUN mkdir -p /app/data

EXPOSE 9000 9102

# Default to show help; override in k8s CMD/args
CMD ["firecore", "--help"]


