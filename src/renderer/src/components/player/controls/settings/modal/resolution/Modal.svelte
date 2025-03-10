<script lang="ts">
  import { RESOLUTIONS } from "@/backend/torrent/common/types";
  import { resolution } from "../../../../common/store";
  import FieldModal from "../common/FieldModal.svelte";
  import { Field } from "../common/types";
  import Icon from "./Icon.svelte";
  import Radio from "../common/Radio.svelte";
</script>

<FieldModal field={Field.Resolution}>
  <Icon slot="icon" />
  <Radio
    slot="contents"
    variants={RESOLUTIONS}
    bind:currentVariant={$resolution}
    variantToString={(variant) => `${variant}p`}
  />
</FieldModal>
