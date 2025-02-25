import "webtorrent";
import { Server as HttpServer } from "http";


declare module "webtorrent" {
    export interface TorrentOptions {
        deselect?: boolean;
    }
    export interface ServerBase {
        listen: HttpServer["listen"];

    }
}