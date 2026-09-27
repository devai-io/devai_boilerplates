use axum::extract::{Path, State};
use axum::http::StatusCode;
use mongodb::bson::oid::ObjectId;
use mongodb::bson::{DateTime, doc};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::AppState;
use crate::auth::AuthUser;
use crate::db::is_duplicate_key;
use crate::error::{ApiError, Json};

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
            // chars(), not bytes, so the excerpt never splits a UTF-8 sequence.
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
    let title = input.title.trim();
    if title.is_empty() || input.body.trim().is_empty() {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "title and body are required",
        ));
    }

    let now = DateTime::now();
    let mut post = Post {
        id: ObjectId::new(),
        title: title.to_string(),
        slug: String::new(),
        body: input.body,
        published: false,
        author_id,
        created_at: now,
        updated_at: now,
    };
    save(&state, &mut post, &slugify(title)).await?;
    Ok((StatusCode::CREATED, Json(post_json(&post))))
}

pub async fn update(
    State(state): State<AppState>,
    AuthUser(user_id): AuthUser,
    Path(id): Path<String>,
    Json(input): Json<UpdatePost>,
) -> Result<Json<Value>, ApiError> {
    let mut post = find_own_post(&state, &id, user_id).await?;

    // The slug follows the title; an unchanged title keeps its slug.
    let mut slug = post.slug.clone();
    if let Some(title) = input.title {
        let title = title.trim();
        if title.is_empty() {
            return Err(ApiError::new(
                StatusCode::BAD_REQUEST,
                "title cannot be empty",
            ));
        }
        if title != post.title {
            post.title = title.to_string();
            slug = slugify(title);
        }
    }
    if let Some(body) = input.body {
        post.body = body;
    }
    if let Some(published) = input.published {
        post.published = published;
    }
    post.updated_at = DateTime::now();

    save(&state, &mut post, &slug).await?;
    Ok(Json(post_json(&post)))
}

pub async fn delete(
    State(state): State<AppState>,
    AuthUser(user_id): AuthUser,
    Path(id): Path<String>,
) -> Result<StatusCode, ApiError> {
    let post = find_own_post(&state, &id, user_id).await?;
    state.db.posts.delete_one(doc! { "_id": post.id }).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// 404 if the post doesn't exist (a malformed id can't name one), 403 if
/// it belongs to someone else.
async fn find_own_post(state: &AppState, id: &str, user_id: ObjectId) -> Result<Post, ApiError> {
    let id = ObjectId::parse_str(id).map_err(|_| post_not_found())?;
    let post = state
        .db
        .posts
        .find_one(doc! { "_id": id })
        .await?
        .ok_or_else(post_not_found)?;
    if post.author_id != user_id {
        return Err(ApiError::new(StatusCode::FORBIDDEN, "not your post"));
    }
    Ok(post)
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

/// Upserts `post` (so it both creates and updates), trying `base`, `base-2`,
/// `base-3`, ... as its slug until the unique index accepts one (capped, then
/// the error escapes).
async fn save(state: &AppState, post: &mut Post, base: &str) -> Result<(), ApiError> {
    let mut n = 1;
    loop {
        post.slug = if n == 1 {
            base.to_string()
        } else {
            format!("{base}-{n}")
        };
        let result = state
            .db
            .posts
            .replace_one(doc! { "_id": post.id }, &*post)
            .upsert(true)
            .await;
        match result {
            Err(err) if is_duplicate_key(&err) && n < 50 => n += 1,
            result => return result.map(|_| ()).map_err(ApiError::from),
        }
    }
}

/// Lowercases the title and collapses every non-alphanumeric run into a
/// single dash: "Hello, World!" -> "hello-world".
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
