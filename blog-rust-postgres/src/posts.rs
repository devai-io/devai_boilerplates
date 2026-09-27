use axum::extract::{Path, State};
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::AppState;
use crate::auth::AuthUser;
use crate::error::{ApiError, Json};

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
    // left() counts characters, not bytes, so the excerpt never splits a UTF-8 sequence.
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
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "title and body are required",
        ));
    }

    let post = with_unique_slug(&slugify(title), |slug| {
        sqlx::query_as::<_, Post>(
            "INSERT INTO posts (title, slug, body, author_id) VALUES ($1, $2, $3, $4) RETURNING *",
        )
        .bind(title)
        .bind(slug)
        .bind(&input.body)
        .bind(author_id)
        .fetch_one(&state.pool)
    })
    .await?;
    Ok((StatusCode::CREATED, Json(post)))
}

pub async fn update(
    State(state): State<AppState>,
    AuthUser(user_id): AuthUser,
    Path(id): Path<String>,
    Json(input): Json<UpdatePost>,
) -> Result<Json<Post>, ApiError> {
    let post = find_own_post(&state, &id, user_id).await?;

    let title = match input.title.as_deref().map(str::trim) {
        Some("") => {
            return Err(ApiError::new(
                StatusCode::BAD_REQUEST,
                "title cannot be empty",
            ));
        }
        Some(title) => title.to_string(),
        None => post.title.clone(),
    };
    // The slug follows the title; an unchanged title keeps its slug.
    let slug = if title == post.title {
        post.slug
    } else {
        slugify(&title)
    };
    let body = input.body.unwrap_or(post.body);
    let published = input.published.unwrap_or(post.published);

    let post = with_unique_slug(&slug, |slug| {
        sqlx::query_as::<_, Post>(
            "UPDATE posts SET title = $1, slug = $2, body = $3, published = $4, updated_at = now() \
             WHERE id = $5 RETURNING *",
        )
        .bind(&title)
        .bind(slug)
        .bind(&body)
        .bind(published)
        .bind(post.id)
        .fetch_one(&state.pool)
    })
    .await?;
    Ok(Json(post))
}

pub async fn delete(
    State(state): State<AppState>,
    AuthUser(user_id): AuthUser,
    Path(id): Path<String>,
) -> Result<StatusCode, ApiError> {
    let post = find_own_post(&state, &id, user_id).await?;
    sqlx::query("DELETE FROM posts WHERE id = $1")
        .bind(post.id)
        .execute(&state.pool)
        .await?;
    Ok(StatusCode::NO_CONTENT)
}

/// 404 if the post doesn't exist (a malformed id can't name one), 403 if
/// it belongs to someone else.
async fn find_own_post(state: &AppState, id: &str, user_id: Uuid) -> Result<Post, ApiError> {
    let id = Uuid::parse_str(id).map_err(|_| post_not_found())?;
    let post = sqlx::query_as::<_, Post>("SELECT * FROM posts WHERE id = $1")
        .bind(id)
        .fetch_optional(&state.pool)
        .await?
        .ok_or_else(post_not_found)?;
    if post.author_id != user_id {
        return Err(ApiError::new(StatusCode::FORBIDDEN, "not your post"));
    }
    Ok(post)
}

fn post_not_found() -> ApiError {
    ApiError::new(StatusCode::NOT_FOUND, "post not found")
}

/// Runs `write` with `base`, then `base-2`, `base-3`, ... until the unique
/// constraint on `posts.slug` stops complaining (capped, then the error escapes).
async fn with_unique_slug<T, F>(
    base: &str,
    mut write: impl FnMut(String) -> F,
) -> Result<T, ApiError>
where
    F: Future<Output = Result<T, sqlx::Error>>,
{
    let mut n = 1;
    loop {
        let slug = if n == 1 {
            base.to_string()
        } else {
            format!("{base}-{n}")
        };
        match write(slug).await {
            Err(sqlx::Error::Database(db)) if db.is_unique_violation() && n < 50 => n += 1,
            result => return result.map_err(ApiError::from),
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
