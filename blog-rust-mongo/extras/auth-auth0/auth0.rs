//! Auth0 auth — drop-in replacement for the local JWT verifier in `src/auth.rs`.
//!
//! Validates Auth0 access tokens (RS256) against the tenant's JWKS, checking
//! both issuer and audience. See the README in this directory for the swap.

use std::sync::Mutex;
use std::time::{Duration, Instant};

use axum::extract::FromRequestParts;
use axum::http::{StatusCode, header, request::Parts};
use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};
use serde::Deserialize;

use crate::error::ApiError;

/// The authenticated Auth0 user id (e.g. `auth0|64f1c...`) — a string, not an
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
        validation.set_issuer(&[format!("https://{}/", domain()?)]);
        validation.set_audience(&[audience()?]);
        validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);

        let data = decode::<Claims>(token, &key, &validation).map_err(|_| unauthorized())?;
        Ok(AuthUser(data.claims.sub))
    }
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
}

static JWKS: Mutex<Option<(Instant, JwkSet)>> = Mutex::new(None);

/// Looks `kid` up in the cached JWKS. An unknown kid means Auth0 rotated its
/// keys, so the set is refetched — at most once a minute, so forged kids
/// can't turn every request into a call to Auth0.
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

    let url = format!("https://{}/.well-known/jwks.json", domain()?);
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

/// e.g. `your-tenant.us.auth0.com` (no scheme, no trailing slash).
fn domain() -> Result<String, ApiError> {
    std::env::var("AUTH0_DOMAIN").map_err(|_| ApiError::internal("AUTH0_DOMAIN is not set"))
}

/// The API identifier configured in Auth0 (Applications → APIs).
fn audience() -> Result<String, ApiError> {
    std::env::var("AUTH0_AUDIENCE").map_err(|_| ApiError::internal("AUTH0_AUDIENCE is not set"))
}
