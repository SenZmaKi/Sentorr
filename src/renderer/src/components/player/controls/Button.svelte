<script lang="ts">
  import { hoverManager } from "./common/functions";
  export let style = "";
  export let onClick: () => void;
  export let isHovering = false
  const { onPointerEnter, onPointerLeave } = hoverManager();
</script>

<button
  on:click={onClick}
  on:pointerenter={() => {
    isHovering = true;
    onPointerEnter();
  }}
  on:pointerleave={() => {
    isHovering = false;
    onPointerLeave();
  }}
  class="hover:scale-150 ease-in-out duration-300"
  style="{style}; width: 15px; height: 15px;"
>
  <slot />
</button>
