<script lang="ts">
  import ImagePlaceholder from "../ImagePlaceholder.svelte";
  import type { BaseResult } from "$backend/imdb/types";
  import ButtonWrapper from "./ButtonWrapper.svelte";
  export let result: BaseResult;
</script>

<ButtonWrapper
  mediaID={result.id}
  class_="w-[144px] m-4 xs-dark shadow-black shadow-lg rounded-lg p-1 flex items-center flex-col cursor-pointer ease-in-out hover:scale-110 duration-300"
>
  <ImagePlaceholder url={result.imageUrl} width={130} height={180} />
  <div class="text-center p-2 font-semibold text-sm opacity-90">{result.title}</div>
</ButtonWrapper>
