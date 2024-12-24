import { computeTorrentScores } from "../../src/backend/torrent/common/functions";
import { test } from "bun:test";
import torrents from "../../src/test-results/piratebay/getSeriesFullSeasonTorrents.json";
import { emptyArrayTest } from "../common/functions";

function prettyFormatBytes(bytes: number) {
    const bytes_in_kb = 1024;
    if (bytes < bytes_in_kb) return `${bytes} B`;
    if (bytes < bytes_in_kb * bytes_in_kb)
        return `${(bytes / bytes_in_kb).toFixed(2)} KB`;
    if (bytes < bytes_in_kb * bytes_in_kb * bytes_in_kb)
        return `${(bytes / (bytes_in_kb * bytes_in_kb)).toFixed(2)} MB`;
    return `${(bytes / (bytes_in_kb * bytes_in_kb * bytes_in_kb)).toFixed(2)} GB`;
}


test("computeTorrentScores", async () => {
    const scores = computeTorrentScores({
        torrents,
        preferredResolution: 720,
    });
    const sortedScores = scores.sort((a, b) => b.score - a.score);
    const prettyScores = sortedScores.map((score) => ({
        ...score,
        size: prettyFormatBytes(score.torrent.sizeBytes),
    }));

    emptyArrayTest("torrent:computeTorrentScores", prettyScores);
})