<script lang="ts">
  import { prettyFormatNumber } from "./functions";

  export let IsDislike: boolean;
  export let count: number;
</script>

<div class="flex mr-2">
  <svg
    class="w-3 mr-1 {IsDislike ? 'rotate-180 items-end' : ''}"
    viewBox="0 -0.5 21 21"
    version="1.1"
    xmlns="http://www.w3.org/2000/svg"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    fill="#ffffff"
    ><g stroke-width="0"></g><g
      stroke-linecap="round"
      stroke-linejoin="round"
    ></g><g >
      <title>like [#ffffff]</title> <desc>Created with Sketch.</desc>
      <defs> </defs>
      <g
        stroke="none"
        stroke-width="1"
        fill="none"
        fill-rule="evenodd"
        data-darkreader-inline-stroke=""
      >
        <g
          transform="translate(-259.000000, -760.000000)"
          fill="#ffffff"
          style="--darkreader-inline-fill: #181a1b;"
          data-darkreader-inline-fill=""
        >
          <g transform="translate(56.000000, 160.000000)">
            <path
              d="M203,620 L207.200006,620 L207.200006,608 L203,608 L203,620 Z M223.924431,611.355 L222.100579,617.89 C221.799228,619.131 220.638976,620 219.302324,620 L209.300009,620 L209.300009,608.021 L211.104962,601.825 C211.274012,600.775 212.223214,600 213.339366,600 C214.587817,600 215.600019,600.964 215.600019,602.153 L215.600019,608 L221.126177,608 C222.97313,608 224.340232,609.641 223.924431,611.355 L223.924431,611.355 Z"
            >
            </path>
          </g>
        </g>
      </g>
    </g></svg
  >
  <span class="text-[9px]">{prettyFormatNumber(count)}</span>
</div>
