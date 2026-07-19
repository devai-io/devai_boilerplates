package main

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

type ctxKey struct{}

// userID returns the authenticated user id ("sub" claim) set by requireAuth.
func userID(r *http.Request) string {
	v, _ := r.Context().Value(ctxKey{}).(string)
	return v
}

func (a *app) register(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := decode(w, r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid json body")
		return
	}
	in.Email = strings.ToLower(strings.TrimSpace(in.Email))
	if !strings.Contains(in.Email, "@") {
		writeErr(w, http.StatusBadRequest, "valid email required")
		return
	}
	if len(in.Password) < 8 {
		writeErr(w, http.StatusBadRequest, "password must be at least 8 characters")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil { // bcrypt rejects passwords longer than 72 bytes
		writeErr(w, http.StatusBadRequest, "password too long")
		return
	}
	var id int64
	err = a.db.QueryRow(r.Context(),
		"INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id",
		in.Email, string(hash)).Scan(&id)
	if isDuplicate(err) {
		writeErr(w, http.StatusConflict, "email already registered")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id, "email": in.Email})
}

func (a *app) login(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := decode(w, r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid json body")
		return
	}
	var (
		id   int64
		hash string
	)
	err := a.db.QueryRow(r.Context(),
		"SELECT id, password_hash FROM users WHERE email = $1",
		strings.ToLower(strings.TrimSpace(in.Email))).Scan(&id, &hash)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusUnauthorized, "invalid email or password")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(in.Password)) != nil {
		writeErr(w, http.StatusUnauthorized, "invalid email or password")
		return
	}
	token, err := a.issueToken(strconv.FormatInt(id, 10))
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"token": token})
}

// issueToken signs an HS256 JWT with sub = user id, valid for 7 days.
func (a *app) issueToken(sub string) (string, error) {
	now := time.Now()
	return jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": sub,
		"iat": now.Unix(),
		"exp": now.Add(7 * 24 * time.Hour).Unix(),
	}).SignedString(a.secret)
}

// requireAuth guards a handler: it validates the Bearer token and makes the
// user id available through userID(r).
func (a *app) requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || raw == "" {
			writeErr(w, http.StatusUnauthorized, "missing bearer token")
			return
		}
		token, err := jwt.Parse(raw,
			func(*jwt.Token) (any, error) { return a.secret, nil },
			jwt.WithValidMethods([]string{"HS256"}),
			jwt.WithExpirationRequired())
		if err != nil {
			writeErr(w, http.StatusUnauthorized, "invalid or expired token")
			return
		}
		sub, err := token.Claims.GetSubject()
		if err != nil || sub == "" {
			writeErr(w, http.StatusUnauthorized, "invalid token subject")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, sub)))
	}
}
