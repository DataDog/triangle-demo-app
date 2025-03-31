FROM rust:latest AS builder

WORKDIR /app

# 1. Cache dependencies first
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# 2. Copy actual source code last
COPY . .

# 3. Rebuild with actual code
RUN cargo build --release

# 4. Final image: minimal
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
  libssl3 \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/signal-source /usr/local/bin/signal-source

CMD ["signal-source"]
