<script lang="ts">
  import HoverWrapper from "./HoverWrapper.svelte";
  import TooltipWrapper from "./TooltipWrapper.svelte";

  export let tooltip: string;
  export let style = "";
  export let onClick: (() => void) | undefined = undefined;
  export let isHovering = false;
  export let button: HTMLButtonElement | undefined = undefined;
</script>

<button bind:this={button} on:click={onClick}>
  <TooltipWrapper {tooltip}>
    <HoverWrapper bind:isHovering>
      <!-- HACK: Button should proabably be here but it breaks when "position: relative" is passed as style -->
      <div
        class={"hover:scale-150 ease-in-out duration-300"}
        style="width: 15px; height: 15px; {style}"
      >
        <slot />
      </div>
    </HoverWrapper>
  </TooltipWrapper>
</button>
