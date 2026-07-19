package main

import (
	"context"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// openDB connects, waits briefly for MongoDB to accept connections (useful
// under docker compose), and ensures the unique indexes the API relies on —
// index creation is idempotent, so this is safe on every start.
func openDB(ctx context.Context, url, name string) (*mongo.Database, error) {
	client, err := mongo.Connect(ctx, options.Client().ApplyURI(url))
	if err != nil {
		return nil, err
	}
	for i := 0; ; i++ {
		if err = client.Ping(ctx, nil); err == nil {
			break
		}
		if i == 9 {
			return nil, fmt.Errorf("ping: %w", err)
		}
		time.Sleep(time.Second)
	}
	db := client.Database(name)
	for coll, field := range map[string]string{"users": "email", "posts": "slug"} {
		_, err := db.Collection(coll).Indexes().CreateOne(ctx, mongo.IndexModel{
			Keys:    bson.D{{Key: field, Value: 1}},
			Options: options.Index().SetUnique(true),
		})
		if err != nil {
			return nil, fmt.Errorf("%s index: %w", coll, err)
		}
	}
	return db, nil
}

// isDuplicate reports whether err is a unique-index violation.
func isDuplicate(err error) bool {
	return mongo.IsDuplicateKeyError(err)
}
