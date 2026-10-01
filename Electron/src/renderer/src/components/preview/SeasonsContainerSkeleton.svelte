<script>
  import EpisodeSkeleton from "./EpisodeSkeleton.svelte";
</script>

<div class="overflow-y-auto w-full">
  <div class="mb-2 ml-2 mt-2">
    <div class="animate-pulse rounded bg-gray-700 h-[80px] w-[250px]"></div>
    <div class="h-[10px] w-full"></div>
    <div class="overflow-y-auto pt-2 h-[670px] w-[98%] items-center">
      <EpisodeSkeleton />
      <EpisodeSkeleton />
      <EpisodeSkeleton />
      <EpisodeSkeleton />
      <EpisodeSkeleton />
      <EpisodeSkeleton />
    </div>
  </div>
  <div class="mb-2 p-2">
    <div class="animate-pulse rounded bg-gray-700 w-[300px] h-[80px]"></div>
  </div>
  <div class="mb-2 p-2">
    <div class="animate-pulse rounded bg-gray-700 w-[300px] h-[80px]"></div>
  </div>
  <div class="mb-2 p-2">
    <div class="animate-pulse rounded bg-gray-700 w-[300px] h-[80px]"></div>
  </div>
</div>
