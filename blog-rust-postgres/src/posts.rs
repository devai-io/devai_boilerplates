use axum::extract::{Path, State};
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::auth::AuthUser;
use crate::error::{ApiError, Json};
use crate::AppState;

#[derive(Serialize, sqlx::FromRow)]
pub struct Post {
    id: Uuid,
    title: String,
    slug: String,
    body: String,
    published: bool,
    author_id: Uuid,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct PostSummary {
    id: Uuid,
    title: String,
    slug: String,
    excerpt: String,
    published_at: DateTime<Utc>,
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

pub async fn list(State(state): State<AppState>) -> Result<Json<Vec<PostSummary>>, ApiError> {
    let posts = sqlx::query_as::<_, PostSummary>(
        "SELECT id, title, slug, left(body, 200) AS excerpt, created_at AS published_at \
         FROM posts WHERE published ORDER BY created_at DESC",
    )
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(posts))
}

pub async fn get_by_slug(
    State(state): State<AppState>,
    Path(slug): Path<String>,
) -> Result<Json<Post>, ApiError> {
    sqlx::query_as::<_, Post>("SELECT * FROM posts WHERE slug = $1 AND published")
        .bind(&slug)
        .fetch_optional(&state.pool)
        .await?
        .map(Json)
        .ok_or_else(post_not_found)
}

pub async fn create(
    State(state): State<AppState>,
    AuthUser(author_id): AuthUser,
    Json(input): Json<CreatePost>,
) -> Result<(StatusCode, Json<Post>), ApiError> {
    let title = input.title.trim();
    if title.is_empty() || input.body.trim().is_empty() {
        return Err(ApiError::new(StatusCode::BAD_REQUEST, "title and body are required"));
    }

    let mut slug = slugify(title);
    for retried in [false, true] {
        let result = sqlx::query_as::<_, Post>(
            "INSERT INTO posts (title, slug, body, author_id) VALUES ($1, $2, $3, $4) RETURNING *",
        )
        .bind(title)
        .bind(&slug)
        .bind(&input.body)
        .bind(author_id)
        .fetch_one(&state.pool)
        .await;

        match result {
            Ok(post) => return Ok((StatusCode::CREATED, Json(post))),
            // Slug already taken: retry once with a random suffix.
            Err(sqlx::Error::Database(db)) if db.is_unique_violation() && !retried => {
                slug = suffixed(&slug);
            }
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
) -> Result<Json<Post>, ApiError> {
    let id = parse_post_id(&id)?;
    let post = sqlx::query_as::<_, Post>("SELECT * FROM posts WHERE id = $1 AND author_id = $2")
        .bind(id)
        .bind(author_id)
        .fetch_optional(&state.pool)
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

    for retried in [false, true] {
        let result = sqlx::query_as::<_, Post>(
            "UPDATE posts SET title = $1, slug = $2, body = $3, published = $4, updated_at = now() \
             WHERE id = $5 RETURNING *",
        )
        .bind(&title)
        .bind(&slug)
        .bind(&body)
        .bind(published)
        .bind(id)
        .fetch_one(&state.pool)
        .await;

        match result {
            Ok(post) => return Ok(Json(post)),
            Err(sqlx::Error::Database(db)) if db.is_unique_violation() && !retried => {
                slug = suffixed(&slug);
            }
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
    let result = sqlx::query("DELETE FROM posts WHERE id = $1 AND author_id = $2")
        .bind(id)
        .bind(author_id)
        .execute(&state.pool)
        .await?;
    if result.rows_affected() == 0 {
        return Err(post_not_found());
    }
    Ok(StatusCode::NO_CONTENT)
}

fn post_not_found() -> ApiError {
    ApiError::new(StatusCode::NOT_FOUND, "post not found")
}

fn parse_post_id(raw: &str) -> Result<Uuid, ApiError> {
    // A malformed id cannot match any post, so it reads as a 404 too.
    Uuid::parse_str(raw).map_err(|_| post_not_found())
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
    format!("{slug}-{}", &Uuid::new_v4().simple().to_string()[..6])
}
