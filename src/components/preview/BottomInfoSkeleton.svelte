<script lang="ts">
  import ReviewSkeleton from "../common/ReviewSkeleton.svelte";
  import SimpleSkeleton from "../common/mediacard/SimpleSkeleton.svelte";
</script>

<div class="">
  <div class="rounded-lg bg-gray-700 h-[80px] w-2/3"></div>
  <div class="flex mb-14">
    <div class="rounded-lg mt-10 bg-gray-700 h-[30px] w-[300px] mr-4"></div>
    <div class="rounded-lg mt-10 bg-gray-700 h-[30px] w-[500px]"></div>
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
