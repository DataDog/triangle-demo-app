package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type Detection struct {
	TowerID  int `json:"tower"`
	Location struct {
		X int `json:"x"`
		Y int `json:"y"`
	} `json:"location"`
	Time int64 `json:"time"`
}

type Signal struct {
	X    int   `json:"x"`
	Y    int   `json:"y"`
	Time int64 `json:"time"`
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	log.Printf("Health check requested from %s", r.RemoteAddr)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	})
}

func handleDetection(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var d Detection
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		log.Printf("Error decoding detection: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	log.Printf("Received detection: %+v", d)
	w.WriteHeader(http.StatusAccepted)
}

func handleSignal(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var s Signal
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		log.Printf("Error decoding signal: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	log.Printf("Received signal: %+v", s)
	w.WriteHeader(http.StatusAccepted)
}

func main() {
	// Set up logging
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Get port from environment or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Set up routes
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/detection", handleDetection)
	http.HandleFunc("/signal", handleSignal)

	// Start server
	log.Printf("Base Tower Service starting on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
