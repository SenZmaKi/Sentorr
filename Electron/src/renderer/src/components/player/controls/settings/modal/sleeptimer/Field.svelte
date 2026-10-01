<script lang="ts">
  import Field from "../common/Field.svelte";
  import { Field as FieldEnum } from "../common/types";
  import Icon from "./Icon.svelte";
  import { remainingTimestamp, sleepTimerMins } from "./common/store";
  import { sleepTimerToString } from "./common/functions";
</script>

<Field field={FieldEnum.SleepTimer}>
  <Icon slot="label-icon" />
  <div slot="value">
    {sleepTimerToString($sleepTimerMins, $remainingTimestamp)}
  </div>
</Field>
