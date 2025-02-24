use axum::{extract::State, response::IntoResponse, Json};
use librqbit::{AddTorrent, AddTorrentOptions};
use serde::{Deserialize, Serialize};

use crate::{error::ServiceError, ApiState};

#[derive(Serialize, Deserialize)]
struct FileInfo {
    name: String,
    url: String,
    web_url: String,
}

#[derive(Serialize, Deserialize)]
pub struct AddTorrentReqJson {
    torrent_id: String,
}

#[derive(Serialize, Deserialize)]
struct AddTorrentResJson {
    id: String,
    files: Vec<FileInfo>,
}
#[axum::debug_handler]
pub async fn add_torrent(
    State(state): State<ApiState>,
    Json(AddTorrentReqJson { torrent_id }): Json<AddTorrentReqJson>,
) -> Result<impl IntoResponse, ServiceError> {
    let mut opts = AddTorrentOptions::default();
    opts.only_files = Some(vec![]);
    opts.overwrite = true;
    let api_result = state
        .api
        .api_add_torrent(AddTorrent::Url(torrent_id.into()), Some(opts))
        .await?;
    let id = api_result.details.info_hash;
    let port = state.server_addr.port();
    let host = state.server_addr.ip();
    let files = api_result
        .details
        .files
        .unwrap_or_default()
        .into_iter()
        .enumerate()
        .map(|(idx, f)| FileInfo {
            name: f.name,
            url: format!("http://{host}:{port}/torrents/{id}/stream/{idx}"),
            web_url: format!("http://{host}:{port}/web/torrents/{id}/stream/{idx}"),
        })
        .collect::<Vec<_>>();
    let res_json = Json(AddTorrentResJson { id, files });
    Ok(res_json)
}
