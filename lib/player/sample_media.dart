// PLACEHOLDER: playback sources until torrent streaming is integrated.
// Every queue position plays one of these openly licensed films in turn, so
// consecutive items always differ. Replace [sampleSource]; callers keep their
// shape. The pool mixes containers and delivery (MP4, MOV, MKV with subtitle
// tracks, HLS) to exercise the player, and starts with a short trailer so
// the end-of-item flow is quick to review.
const _pool = [
  'https://download.blender.org/durian/trailer/sintel_trailer-1080p.mp4',
  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  'https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4',
  'https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov',
  'https://download.blender.org/durian/movies/Sintel.2010.1080p.mkv',
];

Uri sampleSource(int position) => Uri.parse(_pool[position % _pool.length]);
