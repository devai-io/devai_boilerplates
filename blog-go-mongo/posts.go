package main

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// ObjectIDs marshal to their hex form in JSON, so ids appear as strings.
type post struct {
	ID          bson.ObjectID `bson:"_id,omitempty" json:"id"`
	Title       string        `bson:"title" json:"title"`
	Slug        string        `bson:"slug" json:"slug"`
	Body        string        `bson:"body" json:"body"`
	Published   bool          `bson:"published" json:"published"`
	PublishedAt *time.Time    `bson:"published_at" json:"published_at"` // nil until first published
	AuthorID    bson.ObjectID `bson:"author_id" json:"author_id"`
	CreatedAt   time.Time     `bson:"created_at" json:"created_at"`
	UpdatedAt   time.Time     `bson:"updated_at" json:"updated_at"`
}

type postSummary struct {
	ID          bson.ObjectID `json:"id"`
	Title       string        `json:"title"`
	Slug        string        `json:"slug"`
	Excerpt     string        `json:"excerpt"`
	PublishedAt *time.Time    `json:"published_at"`
}

func (a *app) listPosts(w http.ResponseWriter, r *http.Request) {
	cur, err := a.posts.Find(r.Context(), bson.M{"published": true},
		options.Find().SetSort(bson.D{{Key: "published_at", Value: -1}}))
	if err != nil {
		internalErr(w, err)
		return
	}
	defer cur.Close(r.Context())
	out := []postSummary{}
	for cur.Next(r.Context()) {
		var p post
		if err := cur.Decode(&p); err != nil {
			internalErr(w, err)
			return
		}
		out = append(out, postSummary{p.ID, p.Title, p.Slug, excerpt(p.Body), p.PublishedAt})
	}
	if err := cur.Err(); err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *app) getPost(w http.ResponseWriter, r *http.Request) {
	var p post
	err := a.posts.FindOne(r.Context(),
		bson.M{"slug": r.PathValue("slug"), "published": true}).Decode(&p)
	if errors.Is(err, mongo.ErrNoDocuments) {
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
	uid, err := bson.ObjectIDFromHex(userID(r))
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
	now := mongoNow()
	p := post{Title: in.Title, Body: in.Body, AuthorID: uid, CreatedAt: now, UpdatedAt: now}
	insert := func(slug string) error {
		p.Slug = slug
		res, err := a.posts.InsertOne(r.Context(), p)
		if err == nil {
			p.ID = res.InsertedID.(bson.ObjectID)
		}
		return err
	}
	if err := withUniqueSlug(slugify(in.Title), insert); err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, p)
}

func (a *app) updatePost(w http.ResponseWriter, r *http.Request) {
	uid, err := bson.ObjectIDFromHex(userID(r))
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid token subject")
		return
	}
	id, err := bson.ObjectIDFromHex(r.PathValue("id"))
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
	var p post
	err = a.posts.FindOne(r.Context(), bson.M{"_id": id}).Decode(&p)
	if errors.Is(err, mongo.ErrNoDocuments) {
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
	now := mongoNow()
	p.UpdatedAt = now
	if p.Published && p.PublishedAt == nil { // stamped on first publish, then kept
		p.PublishedAt = &now
	}

	update := func(slug string) error {
		p.Slug = slug
		_, err := a.posts.UpdateByID(r.Context(), p.ID, bson.M{"$set": bson.M{
			"title":        p.Title,
			"slug":         slug,
			"body":         p.Body,
			"published":    p.Published,
			"published_at": p.PublishedAt,
			"updated_at":   p.UpdatedAt,
		}})
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
	uid, err := bson.ObjectIDFromHex(userID(r))
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid token subject")
		return
	}
	id, err := bson.ObjectIDFromHex(r.PathValue("id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "post not found")
		return
	}
	var p post
	err = a.posts.FindOne(r.Context(), bson.M{"_id": id}).Decode(&p)
	if errors.Is(err, mongo.ErrNoDocuments) {
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
	if _, err := a.posts.DeleteOne(r.Context(), bson.M{"_id": id}); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// withUniqueSlug runs fn with base, then base-2, base-3, ... until the unique
// index on posts.slug stops complaining (capped, then the error escapes).
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

// mongoNow is the current time at the millisecond precision MongoDB stores,
// so a response matches what later reads return.
func mongoNow() time.Time {
	return time.Now().UTC().Truncate(time.Millisecond)
}
