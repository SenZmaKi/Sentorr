import "typescript";

declare module "typescript" {
    export interface HTMLVideoElement {
        videoTracks: unknown[];
        audioTracks: unknown[];
    }
}