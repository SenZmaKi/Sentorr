mod error;
mod handlers;

use anyhow::{Context, Result};
use axum::{
    routing::{get, post},
    Router,
};
use core::fmt;
use handlers::stream;
use librqbit::{Api, Session};
use std::{net::SocketAddr, path::PathBuf, sync::Arc};
use tower_http::trace::TraceLayer;
use tracing::{info, Level};
use tracing_appender::rolling;
use tracing_subscriber::fmt::time::LocalTime;
use tracing_subscriber::{EnvFilter, FmtSubscriber};

const PORT: u16 = 3000;
const ADDR: [u8; 4] = [127, 0, 0, 1];

pub struct HttpApi {
    api: Api,
    server_addr: SocketAddr,
}

impl HttpApi {
    fn new(api: Api, server_addr: SocketAddr) -> Self {
        Self { api, server_addr }
    }
}

pub type ApiState = Arc<HttpApi>;

#[tokio::main]
async fn main() -> Result<()> {
    setup_tracing()?;
    let api_state = setup_api().await?;
    let app = build_router(api_state.clone());

    let listener = tokio::net::TcpListener::bind(api_state.server_addr).await?;

    info!("Starting server at http://{}", api_state.server_addr);
    axum::serve(listener, app.into_make_service())
        .await
        .context("Failed to start server")?;

    Ok(())
}

fn setup_tracing() -> Result<()> {
    let log_dir = "logs"; 
    let log_file = rolling::daily(log_dir, "torrent-server.log");
    let time_format = time::format_description::parse("[hour]:[minute]:[second]").context("Invalid time format")?;
    let timer = LocalTime::new(time_format);
    FmtSubscriber::builder()
        .with_env_filter(
            EnvFilter::builder()
                .with_default_directive(Level::DEBUG.into())
                .from_env_lossy()
                .add_directive(
                    "librqbit_dht=error"
                        .parse()
                        .context("Invalid tracing directive")?,
                )
                .add_directive(
                    "librqbit::torrent_state::streaming=trace"
                        .parse()
                        .context("Invalid tracing directive")?,
                ),
        )
        .with_writer(log_file)
        .with_ansi(false)
        .with_timer(timer)
        .init();
    Ok(())
}

async fn setup_api() -> Result<ApiState> {
    let server_addr = SocketAddr::from((ADDR, PORT));
    let session = Session::new(PathBuf::from("torrents"))
        .await
        .context("Failed to create librqbit session")?;
    let api = Api::new(session, None);
    Ok(Arc::new(HttpApi::new(api, server_addr)))
}

fn build_router(state: ApiState) -> Router {
    Router::new()
        .route("/torrents/{id}/stream/{file_id}", get(stream::stream_file))
        .route(
            "/web/torrents/{id}/stream/{file_id}",
            get(stream::web_stream_file),
        )
        .route("/torrents", post(handlers::add_torrent::add_torrent))
        .with_state(state)
        .layer(TraceLayer::new_for_http())
}
