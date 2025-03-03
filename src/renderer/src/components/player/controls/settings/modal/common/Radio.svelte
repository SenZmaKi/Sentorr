<script lang="ts">
    import { currentFieldModal } from "./store";

  import { iconHeight, iconWidth } from "./constants";
  type T = $$Generic;

  export let variants: T[] = [];
  export let currentVariant: T;
  export let variantToString: ((variant: T) => string) | undefined = undefined;
  export let onVariantChange: ((variant: T) => void) | undefined = undefined;
</script>

<div class="flex flex-col gap-2 overflow-y-auto">
  {#each variants as variant}
    <button
      class="p-2 hover:bg-gray-700 hover:bg-opacity-80 rounded-xl flex gap-2 items-center justify-center"
      on:click={() => {
        currentVariant = variant;
        onVariantChange && onVariantChange(variant);
        $currentFieldModal = undefined;

      }}
    >
      {#if variant === currentVariant}
        <svg
          height={iconHeight}
          width={iconWidth}
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          stroke="#ffffff"
          ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g
            stroke-linecap="round"
            stroke-linejoin="round"
          ></g><g>
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M20.6097 5.20743C21.0475 5.54416 21.1294 6.17201 20.7926 6.60976L10.7926 19.6098C10.6172 19.8378 10.352 19.9793 10.0648 19.9979C9.77765 20.0166 9.49637 19.9106 9.29289 19.7072L4.29289 14.7072C3.90237 14.3166 3.90237 13.6835 4.29289 13.2929C4.68342 12.9024 5.31658 12.9024 5.70711 13.2929L9.90178 17.4876L19.2074 5.39034C19.5441 4.95258 20.172 4.87069 20.6097 5.20743Z"
              fill="#ffffff"
            ></path>
          </g></svg
        >
      {/if}

      <div
        class="transition duration-300 ease-in-out"
        class:scale-125={currentVariant === variant}
        class:font-bold={currentVariant === variant}
      >
        {variantToString ? variantToString(variant) : variant}
      </div>
    </button>
  {/each}
</div>
