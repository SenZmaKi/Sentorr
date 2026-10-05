/// Small public discovery fallback, bundled rather than fetched at startup.
/// Selected from ngosang/trackerslist trackers_best.txt on 2026-10-05:
/// https://github.com/ngosang/trackerslist
const defaultTorrentTrackers = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.stealth.si:80/announce',
  'udp://tracker.torrent.eu.org:451/announce',
  'udp://open.demonii.com:1337/announce',
  'udp://explodie.org:6969/announce',
  'http://tracker.dler.org:6969/announce',
];
