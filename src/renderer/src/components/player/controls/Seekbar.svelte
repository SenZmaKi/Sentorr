<script lang="ts">
  // https://github.com/ThaUnknown/perfect-seekbar

  import { timeStamp } from "../../common/functions";
  import type { Chapter } from "./common/types";
  import type { ThumbnailGenerator } from "./common/thumbnail";
  import HoverWrapper from "./common/HoverWrapper.svelte";

  export let progress = 0;
  export let buffer = 0;
  export let seek = 0;
  export let length = 0;
  export let thumbnailGenerator: ThumbnailGenerator | undefined = undefined;
  export let accentColor = "#f00";
  export let onSeeking: ((percent: number) => void) | undefined = undefined;
  export let onSeeked: (() => void) | undefined = undefined;
  export let alwaysShowThumb = false;
  export let chapters: Chapter[] = [];

  function clamp(value: number): number {
    return Math.min(Math.max(value, 0), 100);
  }

  function calculatePositionProgress(e: PointerEvent): void {
    const { pageX, currentTarget } = e;
    if (!(currentTarget instanceof HTMLElement)) return;

    const percent = clamp(
      ((pageX - currentTarget.getBoundingClientRect().left) /
        currentTarget.clientWidth) *
        100,
    );
    if (seeking) {
      onSeeking && onSeeking(percent);
      progress = percent;
    }
    if (seek !== percent) {
      seek = percent;
      updateThumbnail(percent);
    }
  }

  function endHover(): void {
    seek = 0;
    showThumbnail = false;
    console.log("hiding thumbnail");
  }

  function startSeeking(e: PointerEvent): void {
    seeking = true;
    calculatePositionProgress(e);

    if (e.pointerId) seekbar?.setPointerCapture(e.pointerId);
  }

  function endSeeking(e: PointerEvent): void {
    seeking = false;
    if (e.pointerId) seekbar?.releasePointerCapture(e.pointerId);
    if (onSeeked) onSeeked();
  }

  function checkThumbActive(progress: number, seek: number): boolean {
    return processedChapters.some(
      ({ offset, size }) =>
        offset + size > progress && offset + size > seek && offset < seek,
    );
  }

  function getCurrentChapterTitle(seek: number): string {
    const chapter = processedChapters.find(
      ({ offset, size }) => offset + size > seek && offset <= seek,
    );
    return chapter ? chapter.text : "";
  }

  async function updateThumbnail(percent: number) {
    if (!thumbnailGenerator) return;
    await thumbnailGenerator.updateThumbnail(percent);
    if (percent !== seek) return;
    showThumbnail = true;
    console.log("showing thumbnail");
  }

  let seekbar: HTMLDivElement | null = null;
  let seeking = false;
  let showThumbnail = false;
  let sum = 0;
  let processedChapters = chapters.map(({ size, text }) => {
    const cloned = {
      size,
      text,
      offset: sum,
      scale: 100 / size,
    };
    sum += size;
    return cloned;
  });
  let seekbarHeight = processedChapters.length ? 25 : 13;
  let thumbnailCanvas: HTMLCanvasElement | null = null;
  $: if (thumbnailGenerator && thumbnailCanvas)
    thumbnailGenerator.setCanvas(thumbnailCanvas);
</script>

<HoverWrapper class="w-full">
  <div
    class="seekbar w-full"
    bind:this={seekbar}
    on:pointerdown={startSeeking}
    on:pointerup={endSeeking}
    on:pointerleave={endHover}
    on:pointermove={calculatePositionProgress}
    style="height: {seekbarHeight}px;--accent: {accentColor};"
  >
    {#each processedChapters as { size, offset, scale }}
      {@const seekPercent = clamp((seek - offset) * scale)}
      <div style="width: {size}%;" class="chapter-wrapper">
        <div
          class="chapter w-full"
          class:active={seekPercent > 0 && seekPercent < 100}
        >
          <div class="base-bar w-full" />
          <div
            class="base-bar"
            style="width: {clamp((buffer - offset) * scale)}%;"
          />
          <div class="base-bar" style="width: {seekPercent}%;" />
          <div
            class="ps-progress-bar"
            style="width: {clamp((progress - offset) * scale)}%;"
          />
        </div>
      </div>
    {:else}
      <div class="chapter-wrapper w-full">
        <div class="chapter w-full">
          <div class="base-bar w-full" />
          <div class="base-bar" style="width: {clamp(buffer)}%;" />
          <div class="base-bar" style="width: {clamp(seek)}%;" />
          <div class="ps-progress-bar" style="width: {clamp(progress)}%;" />
        </div>
      </div>
    {/each}

    <div class="thumb-container center" style="left: {progress}%;">
      <div
        style={alwaysShowThumb ? "width: 13px; height: 13px;" : ""}
        class="thumb"
        class:active={checkThumbActive(progress, seek)}
      />
    </div>

    <div
      class="center hover-container"
      style="--progress: {seek}%; --padding: {thumbnailGenerator
        ? '75px'
        : '15px'};"
    >
      <div class="center">
        <div>{getCurrentChapterTitle(seek) || ""}</div>
        {#if thumbnailGenerator}
          <canvas
            class="thumbnail"
            class:hidden={!showThumbnail}
            bind:this={thumbnailCanvas}
          />
        {/if}
        {#if length}
          <div>{timeStamp(length * (seek / 100))}</div>
        {/if}
      </div>
    </div>
  </div>
</HoverWrapper>

<style>
  .w-full {
    width: 100%;
  }
  .center {
    display: flex;
    justify-content: center;
    align-items: center;
  }
  .seekbar {
    display: flex;
    flex-direction: row;
    cursor: pointer;
    user-select: none;
    touch-action: none;
    position: relative;
    font-weight: 500;
    font-size: 14px;
    color: #eee;
    -webkit-touch-callout: none;
    -webkit-tap-highlight-color: #0000;
  }

  @media (pointer: fine) {
    .seekbar:hover .hover-container {
      display: flex;
    }
  }
  .hover-container {
    display: none;
    position: absolute;
    left: clamp(
      var(--padding),
      var(--progress),
      100% - var(--padding)
    ) !important;
    pointer-events: none;
    white-space: nowrap;
    text-shadow: 0 0 4px rgba(0, 0, 0, 0.75);
  }
  .hover-container > div {
    flex-direction: column;
    gap: 3px;
    position: absolute;
    bottom: -10px;
  }
  .thumbnail {
    bottom: 13px;
    border: #eee 2px solid;
    border-radius: 4px;
  }
  .seekbar:active {
    cursor: grabbing;
  }
  .seekbar:active .chapter div {
    filter: brightness(80%);
  }
  .seekbar:hover .thumb,
  .seekbar:active .thumb {
    width: 13px;
    height: 13px;
  }
  .seekbar:hover .thumb.active,
  .seekbar:active .thumb.active {
    width: 19px;
    height: 19px;
    filter: brightness(120%);
  }
  .thumb-container {
    position: absolute;
    bottom: 4.5px;
  }
  .thumb {
    background: var(--accent);
    position: absolute;
    border-radius: 50%;
    box-sizing: border-box;

    transition:
      width 0.1s cubic-bezier(0.4, 0, 1, 1),
      height 0.1s cubic-bezier(0.4, 0, 1, 1),
      filter 0.1s cubic-bezier(0.4, 0, 1, 1);
  }
  .chapter-wrapper {
    display: flex;
    align-items: flex-end;
    position: relative;
    overflow: hidden;
  }
  .chapter-wrapper + .chapter-wrapper .chapter {
    left: 2px;
  }
  .chapter-wrapper + .chapter-wrapper .chapter div {
    left: -2px;
  }
  .chapter {
    height: 9px;
    display: flex;
    align-items: center;
    position: absolute;
    overflow: hidden;
    left: 0;
  }
  .chapter div {
    height: 3px;
    transition:
      height 0.1s cubic-bezier(0.4, 0, 1, 1),
      filter 0.1s cubic-bezier(0.4, 0, 1, 1);
    position: absolute;
  }
  .base-bar {
    background: rgba(255, 255, 255, 0.2);
  }
  .ps-progress-bar {
    background-color: var(--accent);
  }
  .chapter.active div {
    filter: brightness(120%);
    height: 9px !important;
  }
  .seekbar:hover .chapter div {
    height: 5px;
  }
</style>
