<script lang="ts">
  import Loader from "./Loader.svelte";
</script>

<div class="">
  <div class="">
    <slot />
  </div>
  <div
    class="absolute top-[50%] left-[50%]"
    style="transform: translate(-50%, -50%);"
  >
    <Loader />
  </div>
</div>
