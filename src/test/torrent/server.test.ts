import torrentServer from "@/backend/torrent/server/server";
import assert from "assert";
import { test } from "node:test";

const config = {
  serverPort: 0,
  torrentPort: 0,
  maxConns: 50,
  maxTorrentStreams: 5,
  torrentTimeoutSecs: 10,
};
await torrentServer.start(config);

const MAGNET_URI =
  "magnet:?xt=urn:btih:711EA7C37AEAA53B4B8511EC14C6B2DA477AF37B&dn=Mr.Robot.Season.1-4.S01-04.COMPLETE.1080p.BluRay.WEB.10bit.DD5.1&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.bittor.pw%3A1337%2Fannounce&tr=udp%3A%2F%2Fpublic.popcorn-tracker.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.dler.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969&tr=udp%3A%2F%2Fopen.demonii.com%3A1337%2Fannounce";

test("getTorrentStreams", async () => {
  const streams = await torrentServer.getTorrentStreams(MAGNET_URI);
  assert(streams.length, "streams.length");
});

test("selectTorrentStream", async () => {
  const streams = await torrentServer.getTorrentStreams(MAGNET_URI);
  await torrentServer.selectTorrentStream(streams[0]);
});
