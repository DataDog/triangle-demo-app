package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"locator/models"
	"locator/logic"
	"locator/mongo"
)

func HandleBundle(c *gin.Context) {
	var bundle models.SignalBundle
	if err := c.ShouldBindJSON(&bundle); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON"})
		return
	}

	detection := logic.Triangulate(bundle)
	if err := mongo.InsertDetection(detection); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store detection"})
		return
	}

	c.JSON(http.StatusOK, detection)
}

func Healthz(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
