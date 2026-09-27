use axum::Router;
use axum::routing::get;
use tokio::net::TcpListener;
use tokio::signal::unix::{SignalKind, signal};

// Edit this and rebuild: only this crate recompiles, the dependencies stay cached.
const GREETING: &str = "Hello from rust-docker-pipeline!\n";

#[tokio::main]
async fn main() {
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let app = Router::new()
        .route("/", get(|| async { GREETING }))
        .route("/health", get(|| async { "ok" }));

    let listener = TcpListener::bind(format!("0.0.0.0:{port}"))
        .await
        .expect("cannot bind port");
    println!("listening on :{port}");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .expect("server error");
}

/// `docker stop` sends SIGTERM; finish in-flight requests and exit.
async fn shutdown_signal() {
    let mut sigterm = signal(SignalKind::terminate()).expect("install SIGTERM handler");
    tokio::select! {
        _ = sigterm.recv() => {}
        _ = tokio::signal::ctrl_c() => {}
    }
}
