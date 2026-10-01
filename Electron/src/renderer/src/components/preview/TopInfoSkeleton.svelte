<script lang="ts">
  import ImageSkeleton from "../common/ImageSkeleton.svelte";
</script>

<div class="flex mb-16">
  <div class="mr-4">
    <ImageSkeleton width={300} height={400} animate={true} />
  </div>
  <div class="animate-pulse xxs-dark p-2 h-min">
    <div class="rounded bg-gray-700 w-[400px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[350px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[300px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[200px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[380px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[350px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[200px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[250px] h-[10px] mb-4"></div>
    <div class="rounded bg-gray-700 w-[220px] h-[10px] mb-4"></div>
  </div>
</div>
