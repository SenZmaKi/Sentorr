<script lang="ts">
  import { onDestroy } from "svelte";
  import { videoContainer } from "../common/store";
  import Button from "./common/Button.svelte";

  function invertFullscreen() {
    console.log("invertFullscreen()");
    isFullscreen = document.fullscreenElement === $videoContainer;
    console.log("isFullscreen", isFullscreen);
  }
  async function onClick() {
    if (!$videoContainer) return;
    isFullscreen
      ? await document.exitFullscreen()
      : await $videoContainer.requestFullscreen();
  }

  document.addEventListener("fullscreenchange", invertFullscreen);
  onDestroy(() =>
    document.removeEventListener("fullscreenchange", invertFullscreen),
  );

  let isFullscreen =
    !!$videoContainer && document.fullscreenElement === $videoContainer;
  $: console.log("isFullscreen", isFullscreen);
</script>

<Button tooltip={isFullscreen ? "Exit fullscreen" : "Fullscreen"} {onClick}>
  {#if isFullscreen}
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"
      ><g stroke-width="0"></g><g stroke-linecap="round" stroke-linejoin="round"
      ></g><g>
        <path
          d="M7 9C8.10457 9 9 8.10457 9 7V3C9 2.44772 8.55228 2 8 2C7.44772 2 7 2.44772 7 3V7H3C2.44772 7 2 7.44772 2 8C2 8.55228 2.44772 9 3 9H7Z"
          fill="#ffffff"
        ></path>
        <path
          d="M17 9C15.8954 9 15 8.10457 15 7V3C15 2.44772 15.4477 2 16 2C16.5523 2 17 2.44772 17 3V7H21C21.5523 7 22 7.44772 22 8C22 8.55228 21.5523 9 21 9H17Z"
          fill="#ffffff"
        ></path>
        <path
          d="M17 15C15.8954 15 15 15.8954 15 17V21C15 21.5523 15.4477 22 16 22C16.5523 22 17 21.5523 17 21V17H21C21.5523 17 22 16.5523 22 16C22 15.4477 21.5523 15 21 15H17Z"
          fill="#ffffff"
        ></path>
        <path
          d="M9 17C9 15.8954 8.10457 15 7 15H3C2.44772 15 2 15.4477 2 16C2 16.5523 2.44772 17 3 17H7V21C7 21.5523 7.44772 22 8 22C8.55228 22 9 21.5523 9 21V17Z"
          fill="#ffffff"
        ></path>
      </g></svg
    >
  {:else}
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"
      ><g stroke-width="0"></g><g stroke-linecap="round" stroke-linejoin="round"
      ></g><g>
        <g>
          <g>
            <path
              d="M8 2H4C2.89543 2 2 2.89543 2 4V8"
              stroke="#ffffff"
              stroke-width="1.5"
              stroke-linecap="round"
            ></path>
            <path
              d="M22 8L22 4C22 2.89543 21.1046 2 20 2H16"
              stroke="#ffffff"
              stroke-width="1.5"
              stroke-linecap="round"
            ></path>
            <path
              d="M16 22L20 22C21.1046 22 22 21.1046 22 20L22 16"
              stroke="#ffffff"
              stroke-width="1.5"
              stroke-linecap="round"
            ></path>
            <path
              d="M8 22L4 22C2.89543 22 2 21.1046 2 20V16"
              stroke="#ffffff"
              stroke-width="1.5"
              stroke-linecap="round"
            ></path>
          </g>
        </g>
      </g></svg
    >
  {/if}
</Button>
