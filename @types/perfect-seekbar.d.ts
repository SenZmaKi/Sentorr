import { SvelteComponent } from "svelte";

declare module "perfect-seekbar" {
  export interface SeekbarProps {
    progress?: number;
    buffer?: number;
    seek?: number;
    length?: number;
    chapters?: { size: number; text?: string }[];
    getThumbnail?: (time: number) => Promise<string>;
    accentColor?: string;
  }

  export interface SeekbarEvents {
    seeking: CustomEvent<number>;
    seeked: CustomEvent<void>;
  }

  export default class Seekbar extends SvelteComponent<
    SeekbarProps,
    SeekbarEvents
  > {}
}
