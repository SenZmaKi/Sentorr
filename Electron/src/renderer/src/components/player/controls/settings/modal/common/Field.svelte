<script lang="ts">
  import Arrow from "./Arrow.svelte";
  import { currentFieldModal } from "./store";
  import type { Field } from "./types";

  export let field: Field;
</script>

<button
  on:click={() => {
    $currentFieldModal = field;
  }}
  class="flex justify-between gap-2 p-2 rounded-xl hover:bg-gray-700 hover:bg-opacity-80 "
>
  <div class="flex gap-2">
    <slot name="label-icon" />
    <div>{field}</div>
  </div>
  <div class="flex gap-2">
    <slot name="value" />
    <Arrow direction="right" />
  </div>
</button>
