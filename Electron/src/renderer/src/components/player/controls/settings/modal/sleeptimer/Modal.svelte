<script lang="ts">
  import FieldModal from "../common/FieldModal.svelte";
  import Radio from "../common/Radio.svelte";
  import { Field } from "../common/types";
  import Icon from "./Icon.svelte";
  import { sleepTimerToString } from "./common/functions";
  import { sleepTimerMins } from "./common/store";
  import { remainingTimestamp } from "./common/store";
</script>

<FieldModal field={Field.SleepTimer}>
  <Icon slot="icon" />
  <Radio
    slot="contents"
    bind:currentVariant={$sleepTimerMins}
    variants={[undefined, 10, 20, 40, 60, -1]}
    variantToString={(variant) =>
      sleepTimerToString(variant, $remainingTimestamp)}
  />
</FieldModal>
