use axum::extract::FromRequest;
use axum::extract::rejection::JsonRejection;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde::Serialize;
use serde_json::json;

/// JSON body extractor whose rejections use the API's `{"error": ...}` shape.
/// Also doubles as the JSON response type, so handlers deal with one `Json`.
#[derive(FromRequest)]
#[from_request(via(axum::Json), rejection(ApiError))]
pub struct Json<T>(pub T);

impl<T: Serialize> IntoResponse for Json<T> {
    fn into_response(self) -> Response {
        axum::Json(self.0).into_response()
    }
}

pub struct ApiError(pub StatusCode, pub String);

impl ApiError {
    pub fn new(status: StatusCode, message: impl Into<String>) -> Self {
        Self(status, message.into())
    }

    /// Logs the underlying error and hides it from the client.
    pub fn internal(err: impl std::fmt::Display) -> Self {
        eprintln!("internal error: {err}");
        Self::new(StatusCode::INTERNAL_SERVER_ERROR, "internal server error")
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.0, axum::Json(json!({ "error": self.1 }))).into_response()
    }
}

impl From<JsonRejection> for ApiError {
    fn from(rejection: JsonRejection) -> Self {
        // axum answers well-formed JSON of the wrong shape with 422; the API says 400.
        let status = match rejection {
            JsonRejection::JsonDataError(_) => StatusCode::BAD_REQUEST,
            _ => rejection.status(),
        };
        Self::new(status, rejection.body_text())
    }
}

impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        Self::internal(err)
    }
}
