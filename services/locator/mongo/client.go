package mongo

import (
	"context"
	"fmt"
	"os"
	"time"

	"locator/models"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var collection *mongo.Collection

func init() {
	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://mongouser:mongopass@mongodb:27017/triangle?authSource=admin"
	}

	client, err := mongo.NewClient(options.Client().ApplyURI(uri))
	if err != nil {
		panic(fmt.Sprintf("❌ Mongo client error: %v", err))
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := client.Connect(ctx); err != nil {
		panic(fmt.Sprintf("❌ Mongo connect error: %v", err))
	}

	collection = client.Database("triangle").Collection("detections")
	fmt.Println("✅ Connected to MongoDB")
}

func InsertDetection(d models.Detection) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := collection.InsertOne(ctx, d)
	return err
}
