FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy only go.mod first
COPY go.mod ./
RUN go mod download

# Copy the rest of the code
COPY . .

# Run go mod tidy to generate go.sum
RUN go mod tidy

RUN CGO_ENABLED=0 GOOS=linux go build -o locator

FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/locator .

# OpenTelemetry environment variables
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
ENV OTEL_SERVICE_NAME=locator
ENV OTEL_RESOURCE_ATTRIBUTES=service.name=locator

EXPOSE 8000

CMD ["./locator"]
