<script lang="ts">
  import { scale } from "svelte/transition";
  import { safePlay } from "../common/functions";
  import Button from "./Button.svelte";

  export let video: HTMLVideoElement;
  let isPaused = video.paused;
  video.onpause = () => {
    isPaused = video.paused
  };
  video.onplay = () => {
    isPaused = video.paused;
  };
  async function onClick() {
    video.paused ? await safePlay(video) : video.pause();
    isPaused = video.paused;
  }
  video.onclick = onClick;
</script>

<Button style="position: relative;" {onClick}>
  {#if isPaused}
    <svg
      transition:scale
      class="absolute top-0 left-0"
      viewBox="-1 0 12 12"
      version="1.1"
      fill="#ffffff"
    >
      <g stroke-width="0"></g>
      <g
        id="SVGRepo_tracerCarrier"
        stroke-linecap="round"
        stroke-linejoin="round"
      ></g>
      <g id="SVGRepo_iconCarrier">
        <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
          <g transform="translate(-65.000000, -3803.000000)" fill="#ffffff">
            <g id="icons" transform="translate(56.000000, 160.000000)">
              <path
                d="M18.074,3650.7335 L12.308,3654.6315 C10.903,3655.5815 9,3654.5835 9,3652.8985 L9,3645.1015 C9,3643.4155 10.903,3642.4185 12.308,3643.3685 L18.074,3647.2665 C19.306,3648.0995 19.306,3649.9005 18.074,3650.7335"
              ></path>
            </g>
          </g>
        </g>
      </g>
    </svg>
  {:else}
    <svg
      class="absolute top-0 left-0"
      transition:scale
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <g stroke-width="0"></g>
      <g>
        <path
          d="M2 6C2 4.11438 2 3.17157 2.58579 2.58579C3.17157 2 4.11438 2 6 2C7.88562 2 8.82843 2 9.41421 2.58579C10 3.17157 10 4.11438 10 6V18C10 19.8856 10 20.8284 9.41421 21.4142C8.82843 22 7.88562 22 6 22C4.11438 22 3.17157 22 2.58579 21.4142C2 20.8284 2 19.8856 2 18V6Z"
          fill="#ffffff"
        ></path>
        <path
          d="M14 6C14 4.11438 14 3.17157 14.5858 2.58579C15.1716 2 16.1144 2 18 2C19.8856 2 20.8284 2 21.4142 2.58579C22 3.17157 22 4.11438 22 6V18C22 19.8856 22 20.8284 21.4142 21.4142C20.8284 22 19.8856 22 18 22C16.1144 22 15.1716 22 14.5858 21.4142C14 20.8284 14 19.8856 14 18V6Z"
          fill="#ffffff"
        ></path>
      </g>
    </svg>
  {/if}
</Button>
