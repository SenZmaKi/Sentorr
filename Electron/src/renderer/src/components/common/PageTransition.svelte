<script lang="ts">
  import { fly } from "svelte/transition";
  let className = "";
  export { className as class };
</script>

<!--FIX: Transition duration at 3000 or more causing some weird behaviour in transitions between preview pages-->
<div
  class={`absolute w-full ${className}`}
  transition:fly={{ y: 1000, duration: 400 }}
>
  <slot />
</div>
