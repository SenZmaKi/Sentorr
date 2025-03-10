<script lang="ts">
  import { Field as FieldEnum } from "../common/types";
  import Field from "../common/Field.svelte";
  import { resolution } from "../../../../common/store";
  import Icon from "./Icon.svelte";
</script>

<Field field={FieldEnum.Resolution}>
  <Icon slot="label-icon" />
  <div slot="value">
    {$resolution}p
  </div>
</Field>
