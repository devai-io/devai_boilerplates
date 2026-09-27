package auth0auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type ctxKey struct{}

// userID returns the Auth0 user id ("sub" claim, e.g. "auth0|abc123") set by
// the middleware — the same helper the local auth.go provides, so the post
// handlers keep working.
func userID(r *http.Request) string {
	v, _ := r.Context().Value(ctxKey{}).(string)
	return v
}

// newAuth0Auth reads AUTH0_DOMAIN (e.g. your-tenant.eu.auth0.com) and
// AUTH0_AUDIENCE (your API identifier) and returns a middleware that
// validates Auth0-issued RS256 access tokens.
func newAuth0Auth() func(http.HandlerFunc) http.HandlerFunc {
	domain := strings.TrimSuffix(os.Getenv("AUTH0_DOMAIN"), "/")
	audience := os.Getenv("AUTH0_AUDIENCE")
	if domain == "" || audience == "" {
		log.Fatal("AUTH0_DOMAIN and AUTH0_AUDIENCE must be set")
	}
	issuer := "https://" + domain + "/" // Auth0 issuers carry a trailing slash
	keys := &jwksCache{url: issuer + ".well-known/jwks.json"}
	return func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
			if !ok || raw == "" {
				writeAuthErr(w, "missing bearer token")
				return
			}
			token, err := jwt.Parse(raw, keys.keyfunc,
				jwt.WithValidMethods([]string{"RS256"}),
				jwt.WithIssuer(issuer),
				jwt.WithAudience(audience),
				jwt.WithExpirationRequired())
			if err != nil {
				writeAuthErr(w, "invalid or expired token")
				return
			}
			sub, err := token.Claims.GetSubject()
			if err != nil || sub == "" {
				writeAuthErr(w, "invalid token subject")
				return
			}
			next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, sub)))
		}
	}
}

func writeAuthErr(w http.ResponseWriter, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// jwksCache fetches and caches the RSA public keys published at a JWKS URL,
// refetching (at most once a minute) when an unknown key id shows up.
type jwksCache struct {
	url string

	mu      sync.Mutex
	keys    map[string]*rsa.PublicKey
	fetched time.Time
}

func (c *jwksCache) keyfunc(t *jwt.Token) (any, error) {
	kid, _ := t.Header["kid"].(string)
	if kid == "" {
		return nil, fmt.Errorf("token has no kid header")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if key, ok := c.keys[kid]; ok {
		return key, nil
	}
	if time.Since(c.fetched) < time.Minute {
		return nil, fmt.Errorf("unknown key id %q", kid)
	}
	c.fetched = time.Now() // failed fetches are rate-limited too
	if err := c.refresh(); err != nil {
		return nil, err
	}
	key, ok := c.keys[kid]
	if !ok {
		return nil, fmt.Errorf("unknown key id %q", kid)
	}
	return key, nil
}

func (c *jwksCache) refresh() error {
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(c.url)
	if err != nil {
		return fmt.Errorf("fetch jwks: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch jwks: status %d", resp.StatusCode)
	}
	var doc struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&doc); err != nil {
		return fmt.Errorf("decode jwks: %w", err)
	}
	keys := make(map[string]*rsa.PublicKey, len(doc.Keys))
	for _, k := range doc.Keys {
		if k.Kty != "RSA" {
			continue
		}
		n, err := base64.RawURLEncoding.DecodeString(k.N)
		if err != nil {
			continue
		}
		e, err := base64.RawURLEncoding.DecodeString(k.E)
		if err != nil {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{
			N: new(big.Int).SetBytes(n),
			E: int(new(big.Int).SetBytes(e).Int64()),
		}
	}
	c.keys = keys
	return nil
}
