package main

import (
	"github.com/gin-gonic/gin"
	"locator/handlers"
)

func main() {
	r := gin.Default()

	r.POST("/bundle", handlers.HandleBundle)
	r.GET("/healthz", handlers.Healthz)

	r.Run(":8000") // listen on 0.0.0.0:8000
}
