<script lang="ts">
  export let hidden: boolean;
</script>

<div class=" {hidden ? 'hidden' : ''}">
  <div class="">
    <slot />
  </div>
</div>
