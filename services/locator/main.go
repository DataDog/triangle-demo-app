package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"locator/handlers"
	"locator/telemetry"

	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

func main() {
	// Initialize OpenTelemetry
	_, err := telemetry.InitTracer("locator")
	if err != nil {
		log.Fatalf("Failed to initialize tracer: %v", err)
	}
	defer telemetry.ShutdownTracer()

	// Create a context that listens for the interrupt signal from the OS
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	r := gin.Default()

	// Add OpenTelemetry middleware
	r.Use(otelgin.Middleware("locator"))

	// Add your routes
	r.POST("/bundle", handlers.HandleBundle)
	r.GET("/healthz", handlers.Healthz)
	r.GET("/api/locator/detections", handlers.GetDetections)

	// Start the server in a goroutine
	go func() {
		if err := r.Run(":8000"); err != nil {
			log.Printf("Server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	<-ctx.Done()
	log.Println("Shutting down gracefully...")
}
