<script lang="ts">
  import { mediaCardType } from "../common/store";
  import { MediaCardType } from "../common/types";

  export let cardType: MediaCardType;
</script>

<button
  class="hover:scale-125 shake-on-active"
  class:opacity-40={$mediaCardType != cardType}
  on:click={() => ($mediaCardType = cardType)}
>
  <svg
    viewBox="0 0 32 32"
    width="30px"
    height="30px"
    version="1.1"
    xmlns="http://www.w3.org/2000/svg"
  >
    <slot />
  </svg>
</button>
