package main

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed schema.sql
var schemaSQL string

// openDB connects, waits briefly for Postgres to accept connections (useful
// under docker compose), and applies schema.sql — its statements are all
// idempotent, so this is safe on every start.
func openDB(ctx context.Context, url string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, err
	}
	for i := 0; ; i++ {
		if err = pool.Ping(ctx); err == nil {
			break
		}
		if i == 9 {
			return nil, fmt.Errorf("ping: %w", err)
		}
		time.Sleep(time.Second)
	}
	if _, err := pool.Exec(ctx, schemaSQL); err != nil {
		return nil, fmt.Errorf("apply schema: %w", err)
	}
	return pool, nil
}

// isDuplicate reports whether err is a Postgres unique-constraint violation.
func isDuplicate(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
