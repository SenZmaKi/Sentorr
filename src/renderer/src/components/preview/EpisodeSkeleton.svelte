<script>
  import ImageSkeleton from "../common/ImageSkeleton.svelte";
</script>

<div class="rounded flex xs-dark m-7 h-[125px] w-[90%] min-w-[350px]">
  <div>
    <ImageSkeleton height={125} width={180} rounded={true} animate={true} />
  </div>
  <div class="animate-pulse flex-1">
    <div class="flex m-2 h-[15px]">
      <div class="rounded w-[40px] mr-2 bg-gray-700"></div>
      <div class="rounded w-[110px] bg-gray-700"></div>
    </div>
    <div class="m-2 mt-4">
      <div class="rounded w-[90%] h-[5px] bg-gray-700 mb-2"></div>
      <div class="rounded w-[90%] h-[5px] bg-gray-700 mb-2"></div>
      <div class="rounded w-[90%] h-[5px] bg-gray-700 mb-2"></div>
      <div class="rounded w-[90%] h-[5px] bg-gray-700 mb-2"></div>
      <div class="rounded w-[90%] h-[5px] bg-gray-700 mb-2"></div>
    </div>
    <div class="w-[50px] h-[10px] bg-gray-700 ml-2"></div>
  </div>
</div>
