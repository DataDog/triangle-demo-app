FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set OpenTelemetry environment variables
ENV OTEL_SERVICE_NAME=simulation \
  OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.namespace=triangle" \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318 \
  OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
  OTEL_TRACES_EXPORTER=otlp \
  OTEL_METRICS_EXPORTER=otlp \
  OTEL_LOGS_EXPORTER=otlp \
  OTEL_TRACES_SAMPLER=parentbased_always_on \
  OTEL_PYTHON_INSTRUMENTATION_ENABLED=true \
  OTEL_PYTHON_FASTAPI_INSTRUMENTATION_ENABLED=true \
  OTEL_PYTHON_HTTPX_INSTRUMENTATION_ENABLED=true \
  OTEL_PYTHON_PYMONGO_INSTRUMENTATION_ENABLED=true

# Use opentelemetry-instrument to run the application
CMD ["opentelemetry-instrument", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
