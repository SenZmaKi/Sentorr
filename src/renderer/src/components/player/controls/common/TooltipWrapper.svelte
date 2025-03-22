<script lang="ts">
import { tippy } from "../../../common/constants";
import { videoContainer } from "../../common/store";


  export let tooltip: string;
</script>

<div
  use:tippy={{ content: tooltip, appendTo: $videoContainer }}
>
  <slot />
</div>
