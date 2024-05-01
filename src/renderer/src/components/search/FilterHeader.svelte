<script lang="ts">
  export let name: string;
</script>

<div class="flex items-center pb-5">
  <slot/>
  <div class="text-3xl pl-2">{name}</div>
  </div>
