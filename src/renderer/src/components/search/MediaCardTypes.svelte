<script lang="ts">
  import { MediaCardType } from "../common/types";
  import MediaCardTypeButton from "./MediaCardTypeButton.svelte";
</script>

<div class="flex pr-4">
  <MediaCardTypeButton cardType={MediaCardType.Complex}>
    <path d="M8 15h7v-7h-7v7zM17 8v7h7v-7h-7zM17 24h7v-7h-7v7zM8 24h7v-7h-7v7z"
    ></path>
  </MediaCardTypeButton>
  <MediaCardTypeButton cardType={MediaCardType.Simple}>
    <path
      d="M8 12h4v-4h-4v4zM14 12h4v-4h-4v4zM20 8v4h4v-4h-4zM8 18h4v-4h-4v4zM14 18h4v-4h-4v4zM20 18h4v-4h-4v4zM8 24h4v-4h-4v4zM14 24h4v-4h-4v4zM20 24h4v-4h-4v4z"
    ></path>
  </MediaCardTypeButton>
</div>
