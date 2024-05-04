<script lang="ts">
  import EnumFilter from "./EnumFilter.svelte";
  import { MediaTypes } from "$backend/imdb/constants";
  import { mediaTypes } from "./store.js";
</script>

<EnumFilter
  bind:selectedVariants={$mediaTypes}
  variants={MediaTypes}
  viewBox="0 0 50 50"
  name="Type"
>
  <g>
    <path d="M1,38h23v3H12v2h26v-2H26v-3h23V8H1V38z M3,10h44v26H3V10z" />
  </g>
</EnumFilter>
