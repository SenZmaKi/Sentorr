<script lang="ts">
  import { RESOLUTIONS } from "@/backend/torrent/common/types";
  import { resolution, strictResolution } from "../../../../common/store";
  import FieldModal from "../common/FieldModal.svelte";
  import { Field } from "../common/types";
  import Icon from "./Icon.svelte";
  import Radio from "../common/Radio.svelte";
  import Switch from "@/renderer/src/components/common/Switch.svelte";
</script>

<FieldModal field={Field.Resolution}>
  <Icon slot="icon" />
  <div class="flex flex-col gap-4 items-center" slot="contents">
    <Switch label="Strict" bind:checked={$strictResolution} />
    <Radio
      variants={RESOLUTIONS}
      bind:currentVariant={$resolution}
      variantToString={(variant) => `${variant}p`}
    />
  </div>
</FieldModal>
