// Control panel, scenarios, stages, actions, and model notes.
import { DEFAULTS } from "./model.mjs";
import { panelHtml, stagesHtml, notesHtml } from "./kit.mjs";

const stat = (id) => `<span data-stat="${id}"></span>`;

export const PRESETS = {
  quad: {},
  octa: { workers: 8, speedMBps: 16 },
  legacy: { rangeSupport: false, workers: 1 },
  throttled: { speedMBps: 2, workers: 4 },
  flaky: { workers: 4, speedMBps: 6 },
};

export const STAGES = [
  {
    id: "probe",
    title: "Probe server capabilities",
    icon: "target",
    text: "The engine issues a probe request (Range: bytes=0-1). If the server responds with 206 Partial Content and valid Content-Range, parallel connections are enabled and the remote ETag is locked. If 200 OK is returned, it falls back to 1 sequential connection.",
  },
  {
    id: "plan",
    title: "Partition byte ranges",
    icon: "split",
    text: `computePartRanges divides the file size into ${stat("partitions")} equal partitions. A sparse target file is allocated on disk via RandomAccessFile.truncate, ready for out-of-order range writes.`,
  },
  {
    id: "transfer",
    title: "Concurrent transfer & serialized write",
    icon: "hard-drive-download",
    text: `Multiple HTTP connections stream chunks in parallel. To prevent race conditions and file pointer corruption, all writes funnel through _OffsetFileWriter: an asynchronous FIFO queue that seeks to the exact byte offset before writing.`,
  },
  {
    id: "flush",
    title: "SHA-256 block checkpointing",
    icon: "shield",
    text: "As chunks stream in, bytes accumulate in 1 MiB blocks. When a block completes, its SHA-256 hash is computed and written to the .checkpoint ledger file, guaranteeing resume safety across app crashes.",
  },
  {
    id: "recovery",
    title: "Exponential backoff recovery",
    icon: "rotate-ccw",
    text: "If a worker drops connection or receives a 5xx error, it preserves existing verified blocks and pauses for an exponential backoff period (2 << attempt seconds), then reconnects with an If-Range validator.",
  },
  {
    id: "complete",
    title: "Finalize & verify target",
    icon: "check",
    text: "Once every partition has downloaded, the RandomAccessFile is flushed and closed, the .checkpoint journal is cleanly removed, and the file is marked complete.",
  },
];

export const NOTES = [
  "In this visualizer, each slot represents 2 MiB of a 64 MiB file (32 slots total). A production file can be gigabytes with thousands of chunks.",
  "Disk writes are serialized through a single file descriptor (_OffsetFileWriter in Senpwai/Sentorr). Range workers never write directly or race file offsets.",
  "Checkpointing groups incoming bytes into 1 MiB blocks with SHA-256 validation. Only flushed and hash-verified blocks are resumed if a transfer restarts.",
  "When a server lacks 206 Partial Content support, the engine automatically degrades to a single connection downloading sequentially from byte 0.",
  "If the server's ETag changes during a download, the engine discards partial state and restarts from zero to avoid file corruption.",
];

export function explorerHtml() {
  return panelHtml({
    transport: { speeds: [1, 2, 4, 8] },
    presets: [
      { id: "quad", label: "Standard 4-Part", icon: "layout-grid", blurb: "4 parallel HTTP range workers at 8 MB/s" },
      { id: "octa", label: "High Concurrency", icon: "zap", blurb: "8 connections at 16 MB/s high throughput" },
      { id: "legacy", label: "Legacy No-Range", icon: "triangle-alert", blurb: "Server returns 200 OK: falls back to 1 worker" },
      { id: "throttled", label: "Throttled Link", icon: "gauge", blurb: "Token bucket capped to 2 MB/s" },
      { id: "flaky", label: "Flaky Connection", icon: "wifi", blurb: "Simulate drops and watch backoff recovery" },
    ],
    sections: [
      {
        id: "protocol",
        title: "Protocol & Slicing",
        icon: "network",
        purpose: "Configure HTTP range request slicing and server capabilities",
        controls: [
          {
            name: "workers",
            label: "Concurrent connections",
            icon: "users",
            type: "range",
            min: 1,
            max: 8,
            step: 1,
            unit: "",
            value: DEFAULTS.workers,
            help: "Number of parallel HTTP GET range requests (1–8 workers).",
          },
          {
            name: "rangeSupport",
            label: "Range requests (206)",
            icon: "square",
            type: "toggle",
            value: DEFAULTS.rangeSupport,
            help: "Disable to simulate servers returning 200 OK without byte-range support.",
          },
        ],
      },
      {
        id: "flow",
        title: "Flow & Rate Shaping",
        icon: "activity",
        purpose: "Bandwidth throttling and serialized disk persistence",
        controls: [
          {
            name: "speedMBps",
            label: "Bandwidth cap",
            icon: "gauge",
            type: "range",
            min: 1,
            max: 16,
            step: 1,
            unit: "MB/s",
            value: DEFAULTS.speedMBps,
            help: "Maximum throughput enforced by DownloadThrottler across all streams.",
          },
        ],
      },
    ],
    actions: [
      { act: "drop", label: "Drop connection", icon: "wifi", help: "Interrupts a worker to trigger exponential retry" },
      { act: "etag", label: "Invalidate ETag", icon: "rotate-ccw", help: "Simulates remote file replacement on server" },
    ],
    stats: [
      { id: "workers", label: "Active streams", icon: "users" },
      { id: "rate", label: "Throughput", icon: "gauge" },
      { id: "downloaded", label: "Downloaded", icon: "hard-drive-download" },
      { id: "checkpointed", label: "Verified blocks", icon: "shield" },
      { id: "partitions", label: "Range partitions", icon: "split" },
      { id: "retry", label: "Retry backoff", icon: "clock" },
    ],
    stages: STAGES,
    notes: NOTES,
  });
}

export function notes() {
  return notesHtml(NOTES);
}
export function stages() {
  return stagesHtml(STAGES);
}
