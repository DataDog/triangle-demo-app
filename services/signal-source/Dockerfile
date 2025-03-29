FROM rust:latest as builder

WORKDIR /app

# Copy only Cargo files first and build deps
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Now copy actual code
COPY . .

# Rebuild with actual code
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/signal-source /usr/local/bin/signal-source

CMD ["signal-source"]
