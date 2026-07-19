use argon2::password_hash::{rand_core::OsRng, SaltString};
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier};
use axum::extract::{FromRequestParts, State};
use axum::http::{header, request::Parts, StatusCode};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::error::{ApiError, Json};
use crate::AppState;

#[derive(Deserialize)]
pub struct Credentials {
    email: String,
    password: String,
}

#[derive(Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: u64,
}

pub async fn register(
    State(state): State<AppState>,
    Json(input): Json<Credentials>,
) -> Result<(StatusCode, Json<serde_json::Value>), ApiError> {
    let email = input.email.trim().to_lowercase();
    if email.is_empty() || !email.contains('@') {
        return Err(ApiError::new(StatusCode::BAD_REQUEST, "a valid email is required"));
    }
    if input.password.len() < 8 {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        ));
    }

    // Argon2 is deliberately slow; keep it off the async worker threads.
    let password = input.password;
    let hash = tokio::task::spawn_blocking(move || hash_password(&password))
        .await
        .map_err(ApiError::internal)??;

    let inserted = sqlx::query_as::<_, (Uuid, String)>(
        "INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email",
    )
    .bind(&email)
    .bind(&hash)
    .fetch_one(&state.pool)
    .await;

    match inserted {
        Ok((id, email)) => Ok((StatusCode::CREATED, Json(json!({ "id": id, "email": email })))),
        Err(sqlx::Error::Database(db)) if db.is_unique_violation() => {
            Err(ApiError::new(StatusCode::CONFLICT, "email already registered"))
        }
        Err(err) => Err(err.into()),
    }
}

pub async fn login(
    State(state): State<AppState>,
    Json(input): Json<Credentials>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let invalid = || ApiError::new(StatusCode::UNAUTHORIZED, "invalid email or password");

    let email = input.email.trim().to_lowercase();
    let (id, password_hash) =
        sqlx::query_as::<_, (Uuid, String)>("SELECT id, password_hash FROM users WHERE email = $1")
            .bind(&email)
            .fetch_optional(&state.pool)
            .await?
            .ok_or_else(invalid)?;

    let password = input.password;
    let verified = tokio::task::spawn_blocking(move || verify_password(&password, &password_hash))
        .await
        .map_err(ApiError::internal)?;
    if !verified {
        return Err(invalid());
    }

    let claims = Claims {
        sub: id.to_string(),
        exp: jsonwebtoken::get_current_timestamp() + 7 * 24 * 60 * 60, // 7 days
    };
    let token = jsonwebtoken::encode(
        &Header::default(), // HS256
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
    .map_err(ApiError::internal)?;

    Ok(Json(json!({ "token": token })))
}

fn hash_password(password: &str) -> Result<String, ApiError> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(ApiError::internal)
}

fn verify_password(password: &str, hash: &str) -> bool {
    PasswordHash::new(hash)
        .map(|parsed| Argon2::default().verify_password(password.as_bytes(), &parsed).is_ok())
        .unwrap_or(false)
}

/// Extracts the authenticated user's id from `Authorization: Bearer <jwt>`.
pub struct AuthUser(pub Uuid);

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix("Bearer "))
            .ok_or_else(|| ApiError::new(StatusCode::UNAUTHORIZED, "missing bearer token"))?;

        let data = jsonwebtoken::decode::<Claims>(
            token,
            &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
            &Validation::default(), // HS256, expiry checked
        )
        .map_err(|_| ApiError::new(StatusCode::UNAUTHORIZED, "invalid or expired token"))?;

        let id = Uuid::parse_str(&data.claims.sub)
            .map_err(|_| ApiError::new(StatusCode::UNAUTHORIZED, "invalid token subject"))?;
        Ok(AuthUser(id))
    }
}
