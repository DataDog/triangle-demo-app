FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY . .

# Install Go modules and build
RUN go mod tidy && go build -o locator

# Runtime image
FROM alpine:latest
WORKDIR /app

COPY --from=builder /app/locator .

EXPOSE 8000

CMD ["./locator"]
