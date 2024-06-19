<script lang="ts">
  import ImageSkeleton from "../ImageSkeleton.svelte";
</script>

<div class="w-[144px] xs-dark m-4 rounded-lg p-1 flex items-center flex-col">
  <ImageSkeleton animate={true} width={130} height={180} />

  <div class="mt-1 h-[5px] w-[100px] bg-gray-700 mb-3"></div>
</div>
