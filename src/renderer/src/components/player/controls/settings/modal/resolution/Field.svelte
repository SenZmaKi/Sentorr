<script lang="ts">
  import { Field as FieldEnum } from "../common/types";
  import Field from "../common/Field.svelte";
  import { resolution } from "@/renderer/src/components/player/store";
  import Icon from "./Icon.svelte";
</script>

<Field field={FieldEnum.Resolution}>
  <Icon slot="label-icon" />
  <div slot="value">
    {$resolution}p
  </div>
</Field>
