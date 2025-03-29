FROM golang:1.21-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy go mod file
COPY go.mod ./

# Initialize go module and download dependencies
RUN go mod tidy

# Copy source code
COPY . .

# Build the application
RUN go build -o server .

# Add health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
CMD ["./server"]
