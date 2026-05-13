package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	configPath := "config.yaml"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}

	cfg, err := LoadConfig(configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	db, err := NewDB(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	handler := NewHandler(db, cfg)
	addr := fmt.Sprintf(":%d", cfg.Server.Port)

	log.Printf("Server starting on %s", addr)
	if err := http.ListenAndServe(addr, handler.SetupRoutes()); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
