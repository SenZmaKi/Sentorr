<script lang="ts">
  import { hoverManager } from "./common/functions";
  export let style = "";
  export let onClick: () => void;
  const { onPointerEnter, onPointerLeave } = hoverManager();
</script>

<button
  on:click={onClick}
  on:pointerenter={onPointerEnter}
  on:pointerleave={onPointerLeave}
  class="hover:scale-150 ease-in-out duration-300"
  style="{style}; width: 15px; height: 15px;"
>
  <slot />
</button>
