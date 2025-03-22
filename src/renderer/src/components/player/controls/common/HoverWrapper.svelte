<script lang="ts">
  import { isHovering as isHoveringControls } from ".././common/store";

  export let isHovering = false;
</script>

<div
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
