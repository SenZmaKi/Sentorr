<script lang="ts">
  import { hoverManager } from "./common/functions";
  export let style = "";
  export let onClick: (() => void) | undefined = undefined;
  export let isHovering = false;
  export let setHoverScale = true;
  export let setSize = true;
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
  class="{setHoverScale ? 'hover:scale-150 ease-in-out duration-300' : ''}"
  style="{setSize ? 'min-width: 15px; min-height: 15px;' : ''};{style}"
>
  <slot />
</button>
