// https://github.com/ikatson/rqbit/blob/fea00e2d18df97de2fff3e1113fd0076e8f40793/crates/librqbit/src/http_api/handlers/streaming.rs

use crate::error::ServiceError;
use crate::ApiState;
use anyhow::{Context, Result};
use axum::extract::{Path, State};
use axum::http::{self, HeaderMap, HeaderValue, StatusCode};
use axum::response::{Html, IntoResponse};
use librqbit::api::TorrentIdOrHash;
use serde::Deserialize;
use std::collections::HashSet;
use std::io::SeekFrom;
use tokio::io::AsyncSeekExt;
use tracing::{info, trace};

#[derive(Deserialize)]
pub struct Params {
    id: TorrentIdOrHash,
    file_id: usize,
}

async fn select_torrent(id: TorrentIdOrHash, file_id: usize, state: &ApiState) -> Result<()> {
    for t in state
        .api
        .api_torrent_list()
        .torrents
        .iter()
        .filter(|t| t.info_hash != id.to_string())
    {
        let id = TorrentIdOrHash::parse(&t.info_hash)?;
        let mgr = state.api.mgr_handle(id)?;
        if mgr.is_paused() {
            continue;
        }
        mgr.wait_until_initialized().await?;
        state.api.api_torrent_action_pause(id).await?;
        state
            .api
            .api_torrent_action_update_only_files(id, &HashSet::new())
            .await?;
    }
    let mgr = state.api.mgr_handle(id)?;
    if mgr.is_paused() {
        state.api.api_torrent_action_start(id).await?;
    }
    mgr.wait_until_initialized().await?;
    let only_files = HashSet::from([file_id]);
    state
        .api
        .api_torrent_action_update_only_files(id, &only_files)
        .await?;
    Ok(())
}

#[axum::debug_handler]
pub async fn web_stream_file(
    State(state): State<ApiState>,
    Path(Params { id, file_id, .. }): Path<Params>,
) -> Result<impl IntoResponse, ServiceError> {
    let stream_url = format!(
        "http://{}/torrents/{id}/stream/{file_id}",
        state.server_addr
    );
    let html = Html(format!(
        r#"
    <html>
        <head>
            <style>
                body {{
                    margin: 0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    background-color: black;
                }}
                video {{
                    width: 100%;
                    height: 100%;
                    object-fit: cover;
                }}
            </style>
        </head>
        <body>
            <video src="{url}" controls autoplay></video>
        </body>
    </html>
    "#,
        url = stream_url
    ));

    Ok(html.into_response())
}

#[axum::debug_handler]
pub async fn stream_file(
    State(state): State<ApiState>,
    Path(Params { id, file_id, .. }): Path<Params>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ServiceError> {
    info!("Selecting torrent {id} for file {file_id}");
    select_torrent(id, file_id, &state).await?;
    info!("Streaming file {file_id} of torrent {id}");
    let mut stream = state.api.api_stream(id, file_id)?;
    let mut status = StatusCode::OK;
    let mut output_headers = HeaderMap::new();
    output_headers.insert("Accept-Ranges", HeaderValue::from_static("bytes"));

    const DLNA_TRANSFER_MODE: &str = "transferMode.dlna.org";
    const DLNA_GET_CONTENT_FEATURES: &str = "getcontentFeatures.dlna.org";
    const DLNA_CONTENT_FEATURES: &str = "contentFeatures.dlna.org";

    if headers
        .get(DLNA_TRANSFER_MODE)
        .map(|v| matches!(v.as_bytes(), b"Streaming" | b"streaming"))
        .unwrap_or(false)
    {
        output_headers.insert(DLNA_TRANSFER_MODE, HeaderValue::from_static("Streaming"));
    }

    if headers
        .get(DLNA_GET_CONTENT_FEATURES)
        .map(|v| v.as_bytes() == b"1")
        .unwrap_or(false)
    {
        output_headers.insert(
            DLNA_CONTENT_FEATURES,
            HeaderValue::from_static("DLNA.ORG_OP=01"),
        );
    }

    if let Ok(mime) = state.api.torrent_file_mime_type(id, file_id) {
        output_headers.insert(
            http::header::CONTENT_TYPE,
            HeaderValue::from_str(mime).context("bug - invalid MIME")?,
        );
    }

    let range_header = headers.get(http::header::RANGE);
    trace!(torrent_id=%id, file_id=file_id, range=?range_header, "request for HTTP stream");

    if let Some(range) = range_header {
        let offset: Option<u64> = range
            .to_str()
            .ok()
            .and_then(|s| s.strip_prefix("bytes="))
            .and_then(|s| s.strip_suffix('-'))
            .and_then(|s| s.parse().ok());
        if let Some(offset) = offset {
            status = StatusCode::PARTIAL_CONTENT;
            stream
                .seek(SeekFrom::Start(offset))
                .await
                .context("error seeking")?;

            output_headers.insert(
                http::header::CONTENT_LENGTH,
                HeaderValue::from_str(&format!("{}", stream.len() - stream.position()))
                    .context("bug")?,
            );
            output_headers.insert(
                http::header::CONTENT_RANGE,
                HeaderValue::from_str(&format!(
                    "bytes {}-{}/{}",
                    stream.position(),
                    stream.len().saturating_sub(1),
                    stream.len()
                ))
                .context("bug")?,
            );
        }
    } else {
        output_headers.insert(
            http::header::CONTENT_LENGTH,
            HeaderValue::from_str(&format!("{}", stream.len())).context("bug")?,
        );
    }
    let s = tokio_util::io::ReaderStream::with_capacity(stream, 64 * 1024);
    Ok((status, (output_headers, axum::body::Body::from_stream(s))))
}
