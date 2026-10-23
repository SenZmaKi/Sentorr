// The explorer around the bench: what the reader can change, watch and try.
// Every number a control offers is a real setting or a real-world range.
import { DEFAULTS, MAX_PEERS } from "./model.mjs";
import { panelHtml, stagesHtml, notesHtml } from "./kit.mjs";

const d = DEFAULTS;
const stat = (id) => `<span data-stat="${id}"></span>`;

export const PRESETS = {
  healthy: {},
  slow: { swarmMBps: 1, peers: 3 },
  remux: { mbps: 40, pieceMiB: 16, swarmMBps: 8, lengthS: 600 },
  lone: { peers: 1, swarmMBps: 1.6 },
  whole: { aheadMin: 0 },
  small: { pieceMiB: 1, mbps: 16 },
};

export const STAGES = [
  {
    id: "urgent",
    title: "Fill the urgent window",
    icon: "target",
    text: `mpv's read waits on the first missing piece. The engine marks it and the next ones, ${stat("urgent")}, top priority with deadlines ${stat("step")} apart, and holds the download-ahead window back. The fastest peers take the soonest deadlines.`,
  },
  {
    id: "hold",
    title: "Play while holding",
    icon: "play",
    text: "Once 2 s are cached mpv starts. The hold stays on until the player has read an unbroken urgent run since the seek, so every peer keeps feeding playback.",
  },
  {
    id: "ahead",
    title: "Download ahead",
    icon: "hard-drive-download",
    text: `The hold is released. Peers not needed by the urgent window fill pieces up to ${stat("ahead")} past the playhead, rarest first, out of order.`,
  },
  {
    id: "steady",
    title: "Steady",
    icon: "check",
    text: "Everything wanted is verified, so peers park. mpv keeps reading up to 60 s ahead of the playhead.",
  },
  {
    id: "stall",
    title: "Stall and recover",
    icon: "hourglass",
    text: "If the cache empties, mpv pauses (buffering) and resumes at 2 s. A seek cancels stale reads, keeps verified pieces and starts again at step 1.",
  },
];

export const NOTES = [
  "Each peer fetches whole pieces. libtorrent requests 16 KiB blocks, so several peers can share one urgent piece and none sits idle during the start hold.",
  "Peers never choke and have every piece. Rarest-first uses a fixed pseudo-random rarity rather than a live swarm's availability.",
  "Hash checks are instant. In the engine a piece is served only after its SHA-1 verifies.",
  "mpv's cache is the unbroken verified run ahead of the playhead, capped at 60 s; its 128 MiB forward byte limit and the 45 s piece wait are not modelled.",
  "The engine's 3 s no-reads release of the hold is modelled as mpv's cache being full, which is when it stops reading.",
  "The tray holds 36 pieces, so a film is at most 36 pieces long; a real film has thousands.",
];

export function explorerHtml() {
  return panelHtml({
    transport: { speeds: [1, 2, 4, 8, 16] },
    presets: [
      { id: "healthy", label: "Healthy swarm", icon: "wifi", blurb: "The defaults: 2.4× the bitrate" },
      { id: "slow", label: "Slow swarm", icon: "hourglass", blurb: "Below the bitrate: watch it stall" },
      { id: "remux", label: "4K remux", icon: "film", blurb: "40 Mbit/s in 16 MiB pieces" },
      { id: "lone", label: "Lone seeder", icon: "users", blurb: "One peer does everything" },
      { id: "whole", label: "Whole file", icon: "hard-drive-download", blurb: "Download ahead: entire file" },
      { id: "small", label: "Small pieces", icon: "puzzle", blurb: "1 MiB: a wider comb" },
    ],
    sections: [
      {
        id: "network",
        title: "Network",
        icon: "network",
        blurb: "The swarm sending you pieces",
        apply: "live",
        controls: [
          { name: "swarmMBps", label: "Swarm speed", icon: "gauge", type: "range", min: 0.2, max: 10, step: 0.1, digits: 1, unit: "MB/s", value: d.swarmMBps, help: `All peers together, ${stat("ratio")} the film's bitrate. Below 1× playback has to stall.` },
          { name: "peers", label: "Peers", icon: "users", type: "range", min: 1, max: MAX_PEERS, step: 1, value: d.peers, help: "Connections sending pieces. Speed splits unevenly, so some peers are faster than others." },
        ],
      },
      {
        id: "film",
        title: "Film",
        icon: "film",
        blurb: "What is being streamed",
        apply: "restart",
        controls: [
          { name: "mbps", label: "Bitrate", icon: "activity", type: "range", min: 2, max: 40, step: 1, unit: "Mbit/s", value: d.mbps, help: "Sets how many pieces make up 8 s of video (the urgent window) and how far apart deadlines are." },
          { name: "pieceMiB", label: "Piece size", icon: "puzzle", type: "segmented", options: [[1, "1"], [2, "2"], [4, "4"], [8, "8"], [16, "16 MiB"]], value: d.pieceMiB, help: "Chosen by whoever made the torrent. Bigger pieces mean fewer, slower units to fetch and verify." },
          { name: "lengthS", label: "Length", icon: "clock", type: "range", min: 1, max: 60, step: 0.5, format: "duration", value: d.lengthS, help: "Capped at what the tray holds: 36 pieces." },
        ],
      },
      {
        id: "sentorr",
        title: "Sentorr setting",
        icon: "settings-2",
        blurb: "Settings → Streaming",
        apply: "live",
        controls: [
          { name: "aheadMin", label: "Download ahead", icon: "hard-drive-download", type: "select", options: [[1, "1 min"], [2, "2 min"], [5, "5 min"], [10, "10 min (default)"], [30, "30 min"], [0, "Entire file"]], value: d.aheadMin, help: "How far past the playhead pieces are saved to disk. Entire file also fetches what is behind it." },
        ],
      },
    ],
    actions: [
      { act: "back", label: "Back 10 s", icon: "rewind", help: "Usually verified already: plays at once" },
      { act: "ahead", label: "Ahead 10 s", icon: "fast-forward", help: "May land on missing pieces" },
      { act: "middle", label: "Seek to middle", icon: "map-pin", help: "Starts a new urgent window there" },
      { act: "close", label: "Close session", icon: "x", help: "Drops every piece and opens again" },
    ],
    stats: [
      { id: "position", label: "Position", icon: "clock" },
      { id: "cache", label: "mpv cache", icon: "timer", help: "Starts at 2 s, reads to 60 s" },
      { id: "speed", label: "Downloading", icon: "download" },
      { id: "busy", label: "Peers busy", icon: "users" },
      { id: "verified", label: "Verified", icon: "check" },
      { id: "urgent", label: "Urgent window", icon: "target", help: "About 8 s of video" },
      { id: "step", label: "Deadline spacing", icon: "timer-reset", help: "Playback in one piece" },
      { id: "ratio", label: "Swarm vs bitrate", icon: "scale", help: "Below 1× it must stall" },
    ],
    stagesHtml: stagesHtml(STAGES),
  });
}

export const notes = () => notesHtml(NOTES);
