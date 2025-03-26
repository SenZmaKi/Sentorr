import torrentServer from "./server/server";
import { parentPort } from "worker_threads";
import { InvalidStateError } from "@/common/types";
import { getHandle } from "@/common/port";

if (!parentPort) throw new InvalidStateError("No parentPort");
const handle = getHandle(parentPort);
handle("start", torrentServer.start);
handle("clearTorrents", torrentServer.clearTorrents);
handle("getTorrentStreams", torrentServer.getTorrentStreams);
handle("close", torrentServer.close);
handle("selectTorrentStream", torrentServer.selectTorrentStream);
handle("deselectAllTorrentStreams", torrentServer.deselectAllTorrentStreams);
