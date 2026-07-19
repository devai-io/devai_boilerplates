use argon2::password_hash::rand_core::{OsRng, RngCore};
use axum::extract::{Path, State};
use axum::http::StatusCode;
use mongodb::bson::oid::ObjectId;
use mongodb::bson::{doc, DateTime};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::auth::AuthUser;
use crate::db::is_duplicate_key;
use crate::error::{ApiError, Json};
use crate::AppState;

#[derive(Serialize, Deserialize)]
pub struct Post {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub title: String,
    pub slug: String,
    pub body: String,
    pub published: bool,
    pub author_id: ObjectId,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

#[derive(Deserialize)]
pub struct CreatePost {
    title: String,
    body: String,
}

#[derive(Deserialize)]
pub struct UpdatePost {
    title: Option<String>,
    body: Option<String>,
    published: Option<bool>,
}

pub async fn list(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let mut cursor = state
        .db
        .posts
        .find(doc! { "published": true })
        .sort(doc! { "created_at": -1 })
        .await?;

    let mut posts = Vec::new();
    while cursor.advance().await? {
        let post: Post = cursor.deserialize_current().map_err(ApiError::internal)?;
        posts.push(json!({
            "id": post.id.to_hex(),
            "title": post.title,
            "slug": post.slug,
            "excerpt": post.body.chars().take(200).collect::<String>(),
            "published_at": rfc3339(post.created_at),
        }));
    }
    Ok(Json(Value::Array(posts)))
}

pub async fn get_by_slug(
    State(state): State<AppState>,
    Path(slug): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let post = state
        .db
        .posts
        .find_one(doc! { "slug": slug, "published": true })
        .await?
        .ok_or_else(post_not_found)?;
    Ok(Json(post_json(&post)))
}

pub async fn create(
    State(state): State<AppState>,
    AuthUser(author_id): AuthUser,
    Json(input): Json<CreatePost>,
) -> Result<(StatusCode, Json<Value>), ApiError> {
    let title = input.title.trim().to_string();
    if title.is_empty() || input.body.trim().is_empty() {
        return Err(ApiError::new(StatusCode::BAD_REQUEST, "title and body are required"));
    }

    let mut slug = slugify(&title);
    let now = DateTime::now();
    for retried in [false, true] {
        let post = Post {
            id: ObjectId::new(),
            title: title.clone(),
            slug: slug.clone(),
            body: input.body.clone(),
            published: false,
            author_id,
            created_at: now,
            updated_at: now,
        };
        match state.db.posts.insert_one(&post).await {
            Ok(_) => return Ok((StatusCode::CREATED, Json(post_json(&post)))),
            // Slug already taken: retry once with a random suffix.
            Err(err) if is_duplicate_key(&err) && !retried => slug = suffixed(&slug),
            Err(err) => return Err(err.into()),
        }
    }
    unreachable!("second insert attempt always returns");
}

pub async fn update(
    State(state): State<AppState>,
    AuthUser(author_id): AuthUser,
    Path(id): Path<String>,
    Json(input): Json<UpdatePost>,
) -> Result<Json<Value>, ApiError> {
    let id = parse_post_id(&id)?;
    let post = state
        .db
        .posts
        .find_one(doc! { "_id": id, "author_id": author_id })
        .await?
        .ok_or_else(post_not_found)?;

    let title = match input.title.as_deref().map(str::trim) {
        Some("") => return Err(ApiError::new(StatusCode::BAD_REQUEST, "title cannot be empty")),
        Some(title) => title.to_string(),
        None => post.title.clone(),
    };
    // The slug follows the title; an unchanged title keeps the slug stable.
    let mut slug = if title == post.title { post.slug.clone() } else { slugify(&title) };
    let body = input.body.unwrap_or(post.body);
    let published = input.published.unwrap_or(post.published);
    let now = DateTime::now();

    for retried in [false, true] {
        let result = state
            .db
            .posts
            .update_one(
                doc! { "_id": id },
                doc! { "$set": {
                    "title": title.as_str(),
                    "slug": slug.as_str(),
                    "body": body.as_str(),
                    "published": published,
                    "updated_at": now,
                }},
            )
            .await;

        match result {
            Ok(_) => {
                let updated = Post {
                    id: post.id,
                    title,
                    slug,
                    body,
                    published,
                    author_id: post.author_id,
                    created_at: post.created_at,
                    updated_at: now,
                };
                return Ok(Json(post_json(&updated)));
            }
            Err(err) if is_duplicate_key(&err) && !retried => slug = suffixed(&slug),
            Err(err) => return Err(err.into()),
        }
    }
    unreachable!("second update attempt always returns");
}

pub async fn delete(
    State(state): State<AppState>,
    AuthUser(author_id): AuthUser,
    Path(id): Path<String>,
) -> Result<StatusCode, ApiError> {
    let id = parse_post_id(&id)?;
    let result = state
        .db
        .posts
        .delete_one(doc! { "_id": id, "author_id": author_id })
        .await?;
    if result.deleted_count == 0 {
        return Err(post_not_found());
    }
    Ok(StatusCode::NO_CONTENT)
}

/// API shape of a full post (BSON types mapped to plain JSON).
fn post_json(post: &Post) -> Value {
    json!({
        "id": post.id.to_hex(),
        "title": post.title,
        "slug": post.slug,
        "body": post.body,
        "published": post.published,
        "author_id": post.author_id.to_hex(),
        "created_at": rfc3339(post.created_at),
        "updated_at": rfc3339(post.updated_at),
    })
}

fn rfc3339(value: DateTime) -> String {
    value.try_to_rfc3339_string().unwrap_or_default()
}

fn post_not_found() -> ApiError {
    ApiError::new(StatusCode::NOT_FOUND, "post not found")
}

fn parse_post_id(raw: &str) -> Result<ObjectId, ApiError> {
    // A malformed id cannot match any post, so it reads as a 404 too.
    ObjectId::parse_str(raw).map_err(|_| post_not_found())
}

fn slugify(title: &str) -> String {
    let mut slug = String::with_capacity(title.len());
    let mut pending_dash = false;
    for c in title.chars() {
        if c.is_ascii_alphanumeric() {
            if pending_dash && !slug.is_empty() {
                slug.push('-');
            }
            slug.push(c.to_ascii_lowercase());
            pending_dash = false;
        } else {
            pending_dash = true;
        }
    }
    if slug.is_empty() {
        "post".to_string()
    } else {
        slug
    }
}

fn suffixed(slug: &str) -> String {
    // OsRng ships with argon2's password-hash stack; no extra dependency.
    format!("{slug}-{:08x}", OsRng.next_u32())
}
