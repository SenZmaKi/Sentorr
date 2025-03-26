<script lang="ts">
  import { isHovering as isHoveringControls } from ".././common/store";
  let className = "";
  export { className as class };
  export let style = "";

  export let isHovering = false;
</script>

<div
  {style}
  class={className}
  on:pointerenter={() => {
    isHovering = true;
    $isHoveringControls = true;
  }}
  on:pointerleave={() => {
    isHovering = false;
    $isHoveringControls = false;
  }}
>
  <slot />
</div>
