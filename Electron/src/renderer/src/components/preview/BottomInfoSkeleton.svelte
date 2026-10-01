<script lang="ts">
  import ReviewSkeleton from "../common/ReviewSkeleton.svelte";
  import SimpleSkeleton from "../common/mediacard/SimpleSkeleton.svelte";
</script>

<div class="animate-pulse">
  <div class="xs-dark p-2 rounded w-min">
    <div class="rounded-lg bg-gray-700 mb-2 h-[10px] w-[740px]"></div>
    <div class="rounded-lg bg-gray-700 mb-2 h-[10px] w-[735px]"></div>
    <div class="rounded-lg bg-gray-700 mb-2 h-[10px] w-[700px]"></div>
    <div class="rounded-lg bg-gray-700 h-[10px] w-[655px]"></div>
  </div>
  <div class="flex mb-16">
    <div class="rounded xs-dark mt-8 p-2 mr-4">
      <div class="rounded- bg-gray-700 h-[10px] w-[300px]"></div>
    </div>
    <div>
      <div class="rounded xs-dark mt-8 p-2">
        <div class="rounded bg-gray-700 h-[10px] w-[400px]"></div>
      </div>
    </div>
  </div>
  <hr class="h-2 mb-4 border-none bg-gray-700" />
  <div class="flex overflow-y-auto">
    {#each Array.from({ length: 10 }) as _}
      <SimpleSkeleton />
    {/each}
  </div>
  <hr class="h-2 mt-12 mb-2 border-none bg-gray-700" />
  <div class="flex overflow-y-auto">
    {#each Array.from({ length: 10 }) as _}
      <ReviewSkeleton width={256} height={192} />
    {/each}
  </div>
</div>
