mod auth;
mod db;
mod error;
mod posts;

use axum::Router;
use axum::http::StatusCode;
use axum::routing::{get, post};

use crate::error::ApiError;

#[derive(Clone)]
pub struct AppState {
    pub pool: sqlx::PgPool,
    pub jwt_secret: String,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let database_url = env("DATABASE_URL");
    let jwt_secret = env("AUTH_SECRET");
    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(8080);

    let pool = db::connect(&database_url)
        .await
        .expect("failed to connect to Postgres and apply schema.sql");

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .route("/auth/register", post(auth::register))
        .route("/auth/login", post(auth::login))
        .route("/posts", get(posts::list).post(posts::create))
        // axum allows one capture name per path: GET reads it as a slug,
        // PUT/DELETE read it as a post id.
        .route(
            "/posts/{slug_or_id}",
            get(posts::get_by_slug)
                .put(posts::update)
                .delete(posts::delete),
        )
        .fallback(|| async { ApiError::new(StatusCode::NOT_FOUND, "not found") })
        .method_not_allowed_fallback(|| async {
            ApiError::new(StatusCode::METHOD_NOT_ALLOWED, "method not allowed")
        })
        .with_state(AppState { pool, jwt_secret });

    let listener = tokio::net::TcpListener::bind(("0.0.0.0", port))
        .await
        .expect("failed to bind port");
    println!("listening on http://0.0.0.0:{port}");
    axum::serve(listener, app).await.expect("server error");
}

fn env(name: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| panic!("{name} must be set (see .env.example)"))
}
