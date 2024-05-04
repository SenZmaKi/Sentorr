<script lang="ts">
  export let name: string;
  export let viewBox: string;
</script>

<div class="m-2">
<div class="flex items-center pb-5">
  <svg class="w-8 h-8" role="img" {viewBox}>
    <slot name="svgpath" />
  </svg>
  <slot />
  <div class="text-2xl pl-1">{name}</div>
</div>
  <slot name="picker"/>
</div>
