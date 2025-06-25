package mongo

import (
	"context"
	"fmt"
	"os"
	"time"

	"locator/models"

	"go.mongodb.org/mongo-driver/bson"
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
		panic(fmt.Sprintf("Mongo client error: %v", err))
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := client.Connect(ctx); err != nil {
		panic(fmt.Sprintf("Mongo connect error: %v", err))
	}

	collection = client.Database("triangle").Collection("detections")
	fmt.Println("Connected to MongoDB")
}

func InsertDetection(d models.Detection) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := collection.InsertOne(ctx, d)
	return err
}

func FetchDetections() ([]models.Detection, error) {
	var results []models.Detection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	if err := cursor.All(ctx, &results); err != nil {
		return nil, err
	}

	return results, nil
}
