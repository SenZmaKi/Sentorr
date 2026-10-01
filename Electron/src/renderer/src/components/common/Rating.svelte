<script lang="ts">
  export let rating: number;

  export function ratingToColor(rating: number): string {
    let hue = rating * 12;
    return `hsl(${hue}, 100%, 50%)`;
  }

  export function ratingToPercentage(rating: number): string {
    return `${rating * 10}%`;
  }
</script>

<span class="font-extrabold" style="color: {ratingToColor(rating)}"
  >{ratingToPercentage(rating)}</span
>
