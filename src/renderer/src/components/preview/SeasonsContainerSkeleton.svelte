<script>
  import EpisodeSkeleton from "./EpisodeSkeleton.svelte";
</script>

<div class="overflow-y-auto w-1/3">
  <div class="mb-2 p-2">
    <div class="animate-pulse rounded bg-gray-700 h-[80px] w-[300px]"></div>
    <div class="overflow-y-auto pt-2 h-[700px] w-[98%] items-center">
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
