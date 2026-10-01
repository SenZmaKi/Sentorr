<script lang="ts">
  import { Field as FieldEnum } from "../common/types";
  import Field from "../common/Field.svelte";
  import { playbackRate } from "../../../../common/store";
  import Icon from "./Icon.svelte";
</script>

<Field field={FieldEnum.PlaybackRate}>
  <Icon slot="label-icon" />
  <div slot="value">
    {$playbackRate}x
  </div>
</Field>
