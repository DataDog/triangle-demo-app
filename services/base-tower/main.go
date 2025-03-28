package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type Detection struct {
	TowerID  int `json:"tower"`
	Location struct {
		X int `json:"x"`
		Y int `json:"y"`
	} `json:"location"`
	Time int64 `json:"time"`
}

func handleDetection(w http.ResponseWriter, r *http.Request) {
	var d Detection
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	log.Printf("Received detection: %+v", d)
	w.WriteHeader(http.StatusAccepted)
}

func main() {
	http.HandleFunc("/detection", handleDetection)
	log.Println("Base Tower Service running on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
