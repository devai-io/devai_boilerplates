use argon2::password_hash::{rand_core::OsRng, SaltString};
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier};
use axum::extract::{FromRequestParts, State};
use axum::http::{header, request::Parts, StatusCode};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation};
use mongodb::bson::oid::ObjectId;
use mongodb::bson::{doc, DateTime};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::db::is_duplicate_key;
use crate::error::{ApiError, Json};
use crate::AppState;

#[derive(Serialize, Deserialize)]
pub struct User {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub email: String,
    pub password_hash: String,
    pub created_at: DateTime,
}

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

    let user = User {
        id: ObjectId::new(),
        email,
        password_hash: hash,
        created_at: DateTime::now(),
    };
    match state.db.users.insert_one(&user).await {
        Ok(_) => Ok((
            StatusCode::CREATED,
            Json(json!({ "id": user.id.to_hex(), "email": user.email })),
        )),
        Err(err) if is_duplicate_key(&err) => {
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
    let user = state
        .db
        .users
        .find_one(doc! { "email": email.as_str() })
        .await?
        .ok_or_else(invalid)?;

    let password = input.password;
    let hash = user.password_hash;
    let verified = tokio::task::spawn_blocking(move || verify_password(&password, &hash))
        .await
        .map_err(ApiError::internal)?;
    if !verified {
        return Err(invalid());
    }

    let claims = Claims {
        sub: user.id.to_hex(),
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
pub struct AuthUser(pub ObjectId);

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

        let id = ObjectId::parse_str(&data.claims.sub)
            .map_err(|_| ApiError::new(StatusCode::UNAUTHORIZED, "invalid token subject"))?;
        Ok(AuthUser(id))
    }
}
