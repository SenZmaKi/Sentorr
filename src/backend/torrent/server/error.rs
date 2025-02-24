use anyhow;

use axum::{http::StatusCode, response::IntoResponse};
use librqbit::ApiError;

#[derive(Debug)]
pub struct ServiceError {
    source: anyhow::Error,
}

impl IntoResponse for ServiceError {
    fn into_response(self) -> axum::response::Response {
        let (status, error_message) = match self.source.downcast_ref::<ApiError>() {
            Some(e) => (e.status(), e.to_string()),
            None => (StatusCode::INTERNAL_SERVER_ERROR, self.source.to_string()),
        };
        (
            status,
            [("Content-Type", "application/json")],
            format!("{{\"error\":\"{}\"}}", error_message),
        )
            .into_response()
    }
}
impl<E: Into<anyhow::Error> + std::fmt::Debug> From<E> for ServiceError {
    fn from(err: E) -> Self {
        Self { source: err.into() }
    }
}