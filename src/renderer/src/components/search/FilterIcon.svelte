<script lang="ts">
  export let viewBox: string;
</script>

<svg class="w-10 h-10" role="img" {viewBox}>
  <slot />
</svg>
