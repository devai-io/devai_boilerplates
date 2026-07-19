//! Clerk auth — drop-in replacement for the local JWT verifier in `src/auth.rs`.
//!
//! Validates Clerk session tokens (RS256) against your instance's JWKS.
//! See the README in this directory for the full swap instructions.

use axum::extract::FromRequestParts;
use axum::http::{header, request::Parts, StatusCode};
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use tokio::sync::OnceCell;

use crate::error::ApiError;

/// The authenticated Clerk user id (e.g. `user_2f8a...`) — a string, not a
/// UUID. Adjust `posts.author_id` accordingly (see README).
pub struct AuthUser(pub String);

impl<S: Send + Sync> FromRequestParts<S> for AuthUser {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let unauthorized = || ApiError::new(StatusCode::UNAUTHORIZED, "invalid or missing token");

        let token = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix("Bearer "))
            .ok_or_else(unauthorized)?;

        // Pick the signing key matching the token's `kid`.
        let kid = decode_header(token)
            .ok()
            .and_then(|header| header.kid)
            .ok_or_else(unauthorized)?;
        let keys = jwks().await?;
        let jwk = keys.keys.iter().find(|key| key.kid == kid).ok_or_else(unauthorized)?;
        let key = DecodingKey::from_rsa_components(&jwk.n, &jwk.e).map_err(ApiError::internal)?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&[issuer()?]);

        let data = decode::<Claims>(token, &key, &validation).map_err(|_| unauthorized())?;
        Ok(AuthUser(data.claims.sub))
    }
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
}

#[derive(Deserialize)]
struct Jwks {
    keys: Vec<Jwk>,
}

#[derive(Deserialize)]
struct Jwk {
    kid: String,
    n: String,
    e: String,
}

static JWKS: OnceCell<Jwks> = OnceCell::const_new();

/// Fetched once and cached for the lifetime of the process. Clerk rotates
/// signing keys rarely; restart the app to pick up a rotation.
async fn jwks() -> Result<&'static Jwks, ApiError> {
    JWKS.get_or_try_init(|| async {
        let url = format!("{}/.well-known/jwks.json", issuer()?.trim_end_matches('/'));
        reqwest::get(&url)
            .await
            .map_err(ApiError::internal)?
            .error_for_status()
            .map_err(ApiError::internal)?
            .json::<Jwks>()
            .await
            .map_err(ApiError::internal)
    })
    .await
}

/// e.g. `https://your-instance.clerk.accounts.dev` (Clerk dashboard → API keys).
fn issuer() -> Result<String, ApiError> {
    std::env::var("CLERK_ISSUER").map_err(|_| ApiError::internal("CLERK_ISSUER is not set"))
}
