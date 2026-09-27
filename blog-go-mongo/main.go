package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/v2/mongo"
)

type app struct {
	users  *mongo.Collection
	posts  *mongo.Collection
	secret []byte
}

func main() {
	port := envOr("PORT", "8080")
	mongoURL := mustEnv("MONGO_URL")
	mongoDB := mustEnv("MONGO_DB")
	secret := mustEnv("AUTH_SECRET")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	db, err := openDB(ctx, mongoURL, mongoDB)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer db.Client().Disconnect(context.Background())

	a := &app{
		users:  db.Collection("users"),
		posts:  db.Collection("posts"),
		secret: []byte(secret),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("POST /auth/register", a.register)
	mux.HandleFunc("POST /auth/login", a.login)
	mux.HandleFunc("GET /posts", a.listPosts)
	mux.HandleFunc("GET /posts/{slug}", a.getPost)
	mux.HandleFunc("POST /posts", a.requireAuth(a.createPost))
	mux.HandleFunc("PUT /posts/{id}", a.requireAuth(a.updatePost))
	mux.HandleFunc("DELETE /posts/{id}", a.requireAuth(a.deletePost))

	srv := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Printf("listening on :%s", port)
	log.Fatal(srv.ListenAndServe())
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("%s must be set", key)
	}
	return v
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// internalErr logs the cause and hides it from the client.
func internalErr(w http.ResponseWriter, err error) {
	log.Printf("internal error: %v", err)
	writeErr(w, http.StatusInternalServerError, "internal error")
}

// decode reads a JSON request body (capped at 1 MB) into v.
func decode(w http.ResponseWriter, r *http.Request, v any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	return json.NewDecoder(r.Body).Decode(v)
}
