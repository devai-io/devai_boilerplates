package main

import (
	"context"
	"fmt"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// openDB connects, waits for MongoDB to answer (Ping blocks until a server is
// selectable or ctx expires), and ensures the indexes the API relies on —
// index creation is idempotent, so this is safe on every start.
func openDB(ctx context.Context, url, name string) (*mongo.Database, error) {
	client, err := mongo.Connect(options.Client().ApplyURI(url))
	if err != nil {
		return nil, err
	}
	if err := client.Ping(ctx, nil); err != nil {
		return nil, fmt.Errorf("ping: %w", err)
	}
	db := client.Database(name)
	indexes := map[string]mongo.IndexModel{
		"users": {Keys: bson.D{{Key: "email", Value: 1}}, Options: options.Index().SetUnique(true)},
		"posts": {Keys: bson.D{{Key: "slug", Value: 1}}, Options: options.Index().SetUnique(true)},
	}
	for coll, model := range indexes {
		if _, err := db.Collection(coll).Indexes().CreateOne(ctx, model); err != nil {
			return nil, fmt.Errorf("%s index: %w", coll, err)
		}
	}
	return db, nil
}

// isDuplicate reports whether err is a unique-index violation.
func isDuplicate(err error) bool {
	return mongo.IsDuplicateKeyError(err)
}
