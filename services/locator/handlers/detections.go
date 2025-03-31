package handlers

import (
	"net/http"
	"locator/mongo"
	"github.com/gin-gonic/gin"
)

func GetDetections(c *gin.Context) {
	detections, err := mongo.FetchDetections()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch detections"})
		return
	}
	c.JSON(http.StatusOK, detections)
}
