use argon2::{Argon2, PasswordHasher, PasswordVerifier};
use axum::extract::{FromRequestParts, State};
use axum::http::{StatusCode, header, request::Parts};
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::AppState;
use crate::error::{ApiError, Json};

const TOKEN_TTL_SECS: u64 = 7 * 24 * 60 * 60;

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
    if !email.contains('@') {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "a valid email is required",
        ));
    }
    if input.password.chars().count() < 8 {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        ));
    }

    // Argon2 is deliberately slow; keep it off the async worker threads.
    let password = input.password;
    let hash =
        tokio::task::spawn_blocking(move || Argon2::default().hash_password(password.as_bytes()))
            .await
            .map_err(ApiError::internal)?
            .map_err(ApiError::internal)?
            .to_string();

    let inserted = sqlx::query_as::<_, (Uuid, String)>(
        "INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email",
    )
    .bind(&email)
    .bind(&hash)
    .fetch_one(&state.pool)
    .await;

    match inserted {
        Ok((id, email)) => Ok((
            StatusCode::CREATED,
            Json(json!({ "id": id, "email": email })),
        )),
        Err(sqlx::Error::Database(db)) if db.is_unique_violation() => Err(ApiError::new(
            StatusCode::CONFLICT,
            "email already registered",
        )),
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
    let verified = tokio::task::spawn_blocking(move || {
        Argon2::default()
            .verify_password(password.as_bytes(), password_hash.as_str())
            .is_ok()
    })
    .await
    .map_err(ApiError::internal)?;
    if !verified {
        return Err(invalid());
    }

    let claims = Claims {
        sub: id.to_string(),
        exp: jsonwebtoken::get_current_timestamp() + TOKEN_TTL_SECS,
    };
    let token = jsonwebtoken::encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
    .map_err(ApiError::internal)?;

    Ok(Json(json!({ "token": token })))
}

/// Extracts the authenticated user's id from `Authorization: Bearer <jwt>`.
pub struct AuthUser(pub Uuid);

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = ApiError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let unauthorized = || ApiError::new(StatusCode::UNAUTHORIZED, "missing or invalid token");

        let token = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix("Bearer "))
            .ok_or_else(unauthorized)?;

        // Only HS256 is accepted, and `exp` and `sub` must be present; expiry is checked.
        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_required_spec_claims(&["exp", "sub"]);
        let data = jsonwebtoken::decode::<Claims>(
            token,
            &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
            &validation,
        )
        .map_err(|_| unauthorized())?;

        let id = Uuid::parse_str(&data.claims.sub).map_err(|_| unauthorized())?;
        Ok(AuthUser(id))
    }
}
