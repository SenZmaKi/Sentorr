<script lang="ts">
  export let name: string;
  export let viewBox: string;
</script>

<div>
  <div class="flex pb-5">
    <svg class="w-7 h-7" {viewBox}>
      <slot name="svgpath" />
    </svg>
    <div class="text-2xl pl-1">{name}</div>
  </div>
  <slot name="picker" />
</div>
