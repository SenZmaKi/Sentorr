<script lang="ts">
  import { Field as FieldEnum } from "../common/types";
  import Field from "../common/Field.svelte";
  import { playbackSpeed } from "@/renderer/src/components/player/store";
  import Icon from "./Icon.svelte";
</script>

<Field field={FieldEnum.PlaybackSpeed}>
  <Icon slot="label-icon" />
  <div slot="value">
    {$playbackSpeed}
  </div>
</Field>
