package main

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

type post struct {
	ID        int64     `json:"id"`
	Title     string    `json:"title"`
	Slug      string    `json:"slug"`
	Body      string    `json:"body"`
	Published bool      `json:"published"`
	AuthorID  int64     `json:"author_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type postSummary struct {
	ID          int64     `json:"id"`
	Title       string    `json:"title"`
	Slug        string    `json:"slug"`
	Excerpt     string    `json:"excerpt"`
	PublishedAt time.Time `json:"published_at"`
}

const postCols = "id, title, slug, body, published, author_id, created_at, updated_at"

func scanPost(row pgx.Row) (post, error) {
	var p post
	err := row.Scan(&p.ID, &p.Title, &p.Slug, &p.Body, &p.Published,
		&p.AuthorID, &p.CreatedAt, &p.UpdatedAt)
	return p, err
}

func (a *app) listPosts(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.Query(r.Context(),
		"SELECT id, title, slug, body, created_at FROM posts WHERE published ORDER BY created_at DESC")
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()
	out := []postSummary{}
	for rows.Next() {
		var p post
		if err := rows.Scan(&p.ID, &p.Title, &p.Slug, &p.Body, &p.CreatedAt); err != nil {
			internalErr(w, err)
			return
		}
		out = append(out, postSummary{p.ID, p.Title, p.Slug, excerpt(p.Body), p.CreatedAt})
	}
	if err := rows.Err(); err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *app) getPost(w http.ResponseWriter, r *http.Request) {
	p, err := scanPost(a.db.QueryRow(r.Context(),
		"SELECT "+postCols+" FROM posts WHERE slug = $1 AND published", r.PathValue("slug")))
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "post not found")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (a *app) createPost(w http.ResponseWriter, r *http.Request) {
	uid, err := strconv.ParseInt(userID(r), 10, 64)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid token subject")
		return
	}
	var in struct {
		Title string `json:"title"`
		Body  string `json:"body"`
	}
	if err := decode(w, r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid json body")
		return
	}
	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" {
		writeErr(w, http.StatusBadRequest, "title required")
		return
	}
	var p post
	err = withUniqueSlug(slugify(in.Title), func(slug string) error {
		var err error
		p, err = scanPost(a.db.QueryRow(r.Context(),
			"INSERT INTO posts (title, slug, body, author_id) VALUES ($1, $2, $3, $4) RETURNING "+postCols,
			in.Title, slug, in.Body, uid))
		return err
	})
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, p)
}

func (a *app) updatePost(w http.ResponseWriter, r *http.Request) {
	uid, err := strconv.ParseInt(userID(r), 10, 64)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid token subject")
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeErr(w, http.StatusNotFound, "post not found")
		return
	}
	var in struct {
		Title     *string `json:"title"`
		Body      *string `json:"body"`
		Published *bool   `json:"published"`
	}
	if err := decode(w, r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid json body")
		return
	}
	p, err := scanPost(a.db.QueryRow(r.Context(),
		"SELECT "+postCols+" FROM posts WHERE id = $1", id))
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "post not found")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	if p.AuthorID != uid {
		writeErr(w, http.StatusForbidden, "not your post")
		return
	}

	retitled := false
	if in.Title != nil {
		t := strings.TrimSpace(*in.Title)
		if t == "" {
			writeErr(w, http.StatusBadRequest, "title cannot be empty")
			return
		}
		retitled = t != p.Title
		p.Title = t
	}
	if in.Body != nil {
		p.Body = *in.Body
	}
	if in.Published != nil {
		p.Published = *in.Published
	}

	update := func(slug string) error {
		np, err := scanPost(a.db.QueryRow(r.Context(),
			"UPDATE posts SET title = $1, slug = $2, body = $3, published = $4, updated_at = now() WHERE id = $5 RETURNING "+postCols,
			p.Title, slug, p.Body, p.Published, id))
		if err == nil {
			p = np
		}
		return err
	}
	if retitled { // the slug follows the title
		err = withUniqueSlug(slugify(p.Title), update)
	} else {
		err = update(p.Slug)
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (a *app) deletePost(w http.ResponseWriter, r *http.Request) {
	uid, err := strconv.ParseInt(userID(r), 10, 64)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid token subject")
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeErr(w, http.StatusNotFound, "post not found")
		return
	}
	var authorID int64
	err = a.db.QueryRow(r.Context(), "SELECT author_id FROM posts WHERE id = $1", id).Scan(&authorID)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "post not found")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	if authorID != uid {
		writeErr(w, http.StatusForbidden, "not your post")
		return
	}
	if _, err := a.db.Exec(r.Context(), "DELETE FROM posts WHERE id = $1", id); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// withUniqueSlug runs fn with base, then base-2, base-3, ... until the unique
// constraint on posts.slug stops complaining (capped, then the error escapes).
func withUniqueSlug(base string, fn func(slug string) error) error {
	slug := base
	for i := 2; ; i++ {
		err := fn(slug)
		if err == nil || !isDuplicate(err) || i > 50 {
			return err
		}
		slug = fmt.Sprintf("%s-%d", base, i)
	}
}

// slugify lowercases the title and collapses every non-alphanumeric run into
// a single dash: "Hello, World!" -> "hello-world".
func slugify(title string) string {
	var b strings.Builder
	pendingDash := false
	for _, r := range strings.ToLower(title) {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			if pendingDash && b.Len() > 0 {
				b.WriteByte('-')
			}
			b.WriteRune(r)
			pendingDash = false
		} else {
			pendingDash = true
		}
	}
	if b.Len() == 0 {
		return "post"
	}
	return b.String()
}

// excerpt returns the first 200 characters of the body, per the API contract.
func excerpt(body string) string {
	runes := []rune(body)
	if len(runes) <= 200 {
		return body
	}
	return string(runes[:200])
}
