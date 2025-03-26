/// <reference types="typescript/lib/lib.dom" />
import { Ipc } from "@/preload/index";

declare global {
  interface MediaTrack {
    id: string;
    kind: string;
    label: string;
    language: string;
  }

  interface VideoTrack extends MediaTrack {
    selected: boolean;
  }

  interface AudioTrack extends MediaTrack {}

  interface MediaTrackList<T extends MediaTrack> extends EventTarget {
    /** The number of tracks in the list (read-only). */
    readonly length: number;

    /**
     * Returns the `T` track (AudioTrack or VideoTrack) object within the `MediaTrackList`
     * whose `id` matches the specified string.
     * If no match is found, `null` is returned.
     */
    getTrackById(id: string): T | null;

    /** Fired when a new track has been added to the media element. */
    onaddtrack: ((this: MediaTrackList<T>, event: Event) => void) | null;

    /** Fired when a track has been enabled, disabled, or made active/inactive. */
    onchange: ((this: MediaTrackList<T>, event: Event) => void) | null;

    /** Fired when a track has been removed from the media element. */
    onremovetrack: ((this: MediaTrackList<T>, event: Event) => void) | null;

    /** Allows accessing track objects using index notation. */
    [index: number]: T;
  }

  /**
   * https://developer.mozilla.org/en-US/docs/Web/API/VideoTrackList
   */
  interface VideoTrackList extends MediaTrackList<VideoTrack> {
    /** The index of the currently selected track, or -1 if none is selected (read-only). */
    readonly selectedIndex: number;
  }

  /**
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioTrackList
   */
  interface AudioTrackList extends MediaTrackList<AudioTrack> {}

  interface HTMLVideoElement {
    /**
     * Available when `webPreferences.enableBlinkFeatures` includes "AudioVideoTracks".
     */
    videoTracks: VideoTrackList;
    /**
     * Available when `webPreferences.enableBlinkFeatures` includes "AudioVideoTracks".
     */
    audioTracks: AudioTrackList;
  }
  interface TextTrackList {
    [Symbol.iterator](): Iterator<TextTrack>;
  }
  interface TextTrackCueList {
    [Symbol.iterator](): Iterator<TextTrackCue>;
  }
  interface Window {
    /**
     * Invoke a procedure in the main process.
     */
    ipc: Ipc;
  }
}
