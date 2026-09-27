//! Clerk auth — drop-in replacement for the local JWT verifier in `src/auth.rs`.
//!
//! Validates Clerk session tokens (RS256) against your instance's JWKS.
//! See the README in this directory for the full swap instructions.

use std::sync::Mutex;
use std::time::{Duration, Instant};

use axum::extract::FromRequestParts;
use axum::http::{StatusCode, header, request::Parts};
use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};
use serde::Deserialize;

use crate::error::ApiError;

/// The authenticated Clerk user id (e.g. `user_2f8a...`) — a string, not an
/// ObjectId. Adjust `posts.author_id` accordingly (see README).
pub struct AuthUser(pub String);

impl<S: Send + Sync> FromRequestParts<S> for AuthUser {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let unauthorized = || ApiError::new(StatusCode::UNAUTHORIZED, "missing or invalid token");

        let token = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix("Bearer "))
            .ok_or_else(unauthorized)?;
        let kid = decode_header(token)
            .ok()
            .and_then(|header| header.kid)
            .ok_or_else(unauthorized)?;
        let key = signing_key(&kid).await?.ok_or_else(unauthorized)?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&[issuer()?]);
        validation.validate_nbf = true;

        let data = decode::<Claims>(token, &key, &validation).map_err(|_| unauthorized())?;
        Ok(AuthUser(data.claims.sub))
    }
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
}

static JWKS: Mutex<Option<(Instant, JwkSet)>> = Mutex::new(None);

/// Looks `kid` up in the cached JWKS. An unknown kid means Clerk rotated its
/// keys, so the set is refetched — at most once a minute, so forged kids
/// can't turn every request into a call to Clerk.
async fn signing_key(kid: &str) -> Result<Option<DecodingKey>, ApiError> {
    {
        let cache = JWKS.lock().unwrap();
        if let Some((fetched_at, jwks)) = cache.as_ref() {
            if let Some(jwk) = jwks.find(kid) {
                return DecodingKey::from_jwk(jwk).map(Some).map_err(ApiError::internal);
            }
            if fetched_at.elapsed() < Duration::from_secs(60) {
                return Ok(None);
            }
        }
    }

    let url = format!("{}/.well-known/jwks.json", issuer()?);
    let jwks: JwkSet = reqwest::get(&url)
        .await
        .and_then(|response| response.error_for_status())
        .map_err(ApiError::internal)?
        .json()
        .await
        .map_err(ApiError::internal)?;
    let key = jwks.find(kid).map(DecodingKey::from_jwk).transpose();
    *JWKS.lock().unwrap() = Some((Instant::now(), jwks));
    key.map_err(ApiError::internal)
}

/// e.g. `https://your-instance.clerk.accounts.dev` (Clerk dashboard → API keys).
fn issuer() -> Result<String, ApiError> {
    std::env::var("CLERK_ISSUER")
        .map(|issuer| issuer.trim_end_matches('/').to_string())
        .map_err(|_| ApiError::internal("CLERK_ISSUER is not set"))
}
