<script lang="ts">
  import ImageSkeleton from "../common/ImageSkeleton.svelte";
</script>

<div class="flex mb-16">
  <div class="mr-4">
    <ImageSkeleton width={300} height={400} animate={true} />
  </div>
  <div>
    <div class="rounded bg-gray-700 w-[520px] h-16 mb-4"></div>
    <div class="rounded bg-gray-700 w-[400px] h-10 mb-4"></div>
    <div class="rounded bg-gray-700 w-[300px] h-8 mb-4"></div>
    <div class="rounded bg-gray-700 w-[500px] h-8 mb-4"></div>
    <div class="rounded bg-gray-700 w-[150px] h-8"></div>
  </div>
</div>
