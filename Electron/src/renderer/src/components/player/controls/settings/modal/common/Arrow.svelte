<script lang="ts">
  import { iconHeight, iconWidth } from "./constants";
  export let direction: "left" | "right" = "right";
</script>

<svg
  viewBox="0 0 24 24"
  width={iconWidth}
  height={iconHeight}
  class:rotate-180={direction === "left"}
  fill="none"
  xmlns="http://www.w3.org/2000/svg"
  ><g stroke-width="0"></g><g stroke-linecap="round" stroke-linejoin="round"
  ></g><g>
    <path
      d="M10 7L15 12L10 17"
      stroke="#ffffff"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
    ></path>
  </g></svg
>
