export interface TorrentJson {
  id: string;
  name: string;
  info_hash: string;
  leechers: string;
  seeders: string;
  num_files: string;
  size: string;
  username: string;
  added: string;
  status: string;
  category: string;
  imdb: string; // We'd use this but sometimes it's usually an empty string
}
