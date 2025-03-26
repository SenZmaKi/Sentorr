import { join } from "path";
import { Worker } from "worker_threads";
import { getHandleListenerGetter } from "@/common/port";
import { handle } from "@/common/ipc";

export function createWorker() {
  const workerPath = join(__dirname, "worker.js");
  const worker = new Worker(workerPath);
  setupRawHandlers(worker);
  setupPortHandlers(worker);
}

function setupPortHandlers(worker: Worker) {
  const getListener = getHandleListenerGetter(worker);
  handle("clearTorrents", getListener("clearTorrents"));
  handle("getTorrentStreams", getListener("getTorrentStreams"));
  handle("close", getListener("close"));
  handle("selectTorrentStream", getListener("selectTorrentStream"));
  handle("deselectAllTorrentStreams", getListener("deselectAllTorrentStreams"));
  handle("start", getListener("start"));
  handle(
    "getCurrentTorrentStreamStats",
    getListener("getCurrentTorrentStreamStats"),
  );
}

function setupRawHandlers(worker: Worker) {
  worker.on("error", (error) => {
    console.error("Worker error:", error);
    throw error;
  });
  worker.on("messageerror", (error) => {
    console.error("Worker message error:", error);
    throw error;
  });
}
