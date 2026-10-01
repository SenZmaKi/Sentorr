<script lang="ts">
  import Arrow from "./Arrow.svelte";
  import type { Field } from "./types";
  import { currentFieldModal } from "./store";
  import { slide } from "svelte/transition";

  export let field: Field;
</script>

<div class="flex flex-col" transition:slide>
  <button
    on:click={() => ($currentFieldModal = undefined)}
    class="flex gap-2 p-2"
  >
    <div class="flex justify-between w-full">
      <div class="">
        <Arrow direction="left" />
      </div>
      <div class="flex gap-2 justify-center w-full">
        <slot name="icon" />
        <div>{field}</div>
      </div>
    </div>
  </button>
  <div class="h-[2px] w-full bg-gray-700"></div>
  <div class="p-2">
    <slot name="contents" />
  </div>
</div>
