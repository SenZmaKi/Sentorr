<script lang="ts">
  import { RESOLUTIONS } from "@/backend/torrent/sources/common/constants";
  import { resolution, strictResolution } from "../../../../common/store";
  import FieldModal from "../common/FieldModal.svelte";
  import { Field } from "../common/types";
  import Icon from "./Icon.svelte";
  import Radio from "../common/Radio.svelte";
  import Switch from "@/renderer/src/components/common/Switch.svelte";
  import { tippy } from "@/renderer/src/components/common/constants";
</script>

<FieldModal field={Field.Resolution}>
  <Icon slot="icon" />
  <div class="flex flex-col gap-4 items-center" slot="contents">
    <div
      use:tippy={{
        content: $strictResolution
          ? "Force selected resolution only"
          : "Allow better-scoring torrents with other resolutions",
      }}
    >
      <Switch label="Strict" bind:checked={$strictResolution} />
    </div>
    <Radio
      variants={RESOLUTIONS}
      bind:currentVariant={$resolution}
      variantToString={(variant) => `${variant}p`}
    />
  </div>
</FieldModal>
