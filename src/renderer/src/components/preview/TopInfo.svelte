<script lang="ts" ii l>
  import type { Media } from "$backend/imdb/types";
  import ImageSkeleton from "../common/ImageSkeleton.svelte";
  import Rating from "../common/Rating.svelte";
  import { prettyFormatNumber } from "../common/functions";
  export let media: Media;
</script>

<div class="flex mb-16">
  <div class="mr-4 relative h-[400px] w-[300px]">
    <ImageSkeleton url={media.imageUrl} width={300} height={400} />
    {#if media.contentRating}
      <span
        class="opacity-90 absolute top-0 right-0 text-white text-xs font-semibold xs-dark p-1 rounded-bl-md"
        >{media.contentRating}</span
      >
    {/if}
  </div>
  <div class="opacity-90">
    {#if media.title}
      <!-- NOTE: @html to hande stuff like Deadpool &amp; Wolverine I should probably add it in other text sections but I can't be asked-->
      <span class="font-bold text-6xl">{@html media.title}</span>
    {/if}
    <div class="">
      <div class="flex pb-4 pt-6">
        {#if media.rating}
          <div class="flex pr-4">
            <svg
              fill="#ffffff"
              viewBox="0 0 52 52"
              class="pr-2"
              width="30px"
              height="30px"
              data-darkreader-inline-fill=""
              ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g
                id="SVGRepo_tracerCarrier"
                stroke-linecap="round"
                stroke-linejoin="round"
              ></g><g id="SVGRepo_iconCarrier">
                <path
                  d="M27.4133467,3.10133815 L32.0133467,18.1013381 C32.2133467,18.7013381 32.8133467,19.0013381 33.4133467,19.0013381 L48.4133467,19.0013381 C49.9133467,19.0013381 50.5133467,21.0013381 49.3133467,21.9013381 L37.1133467,30.9013381 C36.6133467,31.3013381 36.4133467,32.0013381 36.6133467,32.6013381 L42.4133467,48.0013381 C42.8133467,49.4013381 41.3133467,50.6013381 40.1133467,49.7013381 L27.0133467,39.9013381 C26.5133467,39.5013381 25.8133467,39.5013381 25.2133467,39.9013381 L12.0133467,49.7013381 C10.8133467,50.6013381 9.21334668,49.4013381 9.71334668,48.0013381 L15.3133467,32.6013381 C15.5133467,32.0013381 15.3133467,31.3013381 14.8133467,30.9013381 L2.61334668,21.9013381 C1.41334668,21.0013381 2.11334668,19.0013381 3.51334668,19.0013381 L18.5133467,19.0013381 C19.2133467,19.0013381 19.7133467,18.8013381 19.9133467,18.1013381 L24.6133467,3.00133815 C25.0133467,1.60133815 27.0133467,1.70133815 27.4133467,3.10133815 Z M26.0133467,12.8023264 C26,14.1700393 26,33.5426636 26,34.4953918 C26.1865845,34.6476135 28.9331193,36.6890643 34.2396046,40.6197441 C34.9394191,41.144605 35.8141872,40.4447905 35.5809157,39.6283403 L35.5809157,39.6283403 L32.3085327,31.0201416 C31.9597778,30.2501831 32.3085327,29.7487793 32.7398682,29.4849854 L32.7398682,29.4849854 L39.6048489,24.6961622 C40.3046634,24.1713013 39.9547562,23.0049438 39.0799881,23.0049438 L39.0799881,23.0049438 L31.0206299,23.0049438 C30.6707226,23.0049438 29.7518921,22.8880615 29.5025635,21.9888306 L29.5025635,21.9888306 L26.8332347,13.4436151 C26.7175852,13.0388421 26.3602784,12.8204102 26.0133467,12.8023264 Z"
                ></path>
              </g></svg
            >
            <div class="text-2xl">
              <Rating rating={media.rating} />
            </div>
          </div>
        {/if}
        {#if media.popularityScore}
          <div class="flex items-center pr-4">
            <svg
              class="pr-2"
              width="30px"
              height="30px"
              viewBox="0 0 16 16"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
            >
              <g id="SVGRepo_bgCarrier" stroke-width="0" />

              <g
                id="SVGRepo_tracerCarrier"
                stroke-linecap="round"
                stroke-linejoin="round"
              />

              <g id="SVGRepo_iconCarrier">
                <path
                  fill="#ffffff"
                  d="M16 8.25a.75.75 0 01-1.5 0V5.761l-4.176 4.971a.75.75 0 01-.938.174L5.38 8.68l-4.1 4.1a.75.75 0 01-1.06-1.06l4.5-4.5a.75.75 0 01.894-.126l3.96 2.2L13.6 4.5H10.75a.75.75 0 010-1.5h4.5a.75.75 0 01.75.75v4.5z"
                />
              </g>
            </svg>
            <span class="text-xl">{media.popularityScore}</span>
          </div>
        {/if}
        {#if media.ratingCount}
          <div class="flex items-center">
            <svg
              fill="#ffffff"
              class="pr-2"
              height="30px"
              width="30px"
              version="1.2"
              baseProfile="tiny"
              id="Layer_1"
              xmlns="http://www.w3.org/2000/svg"
              xmlns:xlink="http://www.w3.org/1999/xlink"
              viewBox="0 0 256 256"
              xml:space="preserve"
              ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g
                id="SVGRepo_tracerCarrier"
                stroke-linecap="round"
                stroke-linejoin="round"
              ></g><g id="SVGRepo_iconCarrier">
                <g>
                  <circle cx="193.3" cy="113.5" r="16.8"></circle>
                  <circle cx="172.6" cy="155.3" r="16.8"></circle>
                  <path
                    d="M145.8,175.2h-18.9h-18.9c-11.5,0-18.7,9.5-18.7,21.4v29.3h12.9V200c0-1.2,1-2,2-2c1.2,0,2,0.8,2,2v25.8h41.5V200 c0-1.2,1-2,2-2c1.2,0,2,1,2,2v25.8h12.9v-29.1C164.8,184.7,157.5,175.2,145.8,175.2z"
                  ></path> <circle cx="150.5" cy="113.5" r="16.8"></circle>
                  <path
                    d="M199.9,155.3c0,9.3,7.5,16.8,16.8,16.8c9.3,0,16.8-7.5,16.8-16.8c0-9.3-7.5-16.8-16.8-16.8 C207.4,138.5,199.9,146,199.9,155.3z"
                  ></path>
                  <path
                    d="M198.2,175.2c-11.5,0-18.7,9.5-18.7,21.4v29.3h12.9V200c0-1.2,1-2,2-2c1.2,0,2,0.8,2,2v25.8h41.5V200c0-1.2,1-2,2-2 c1.2,0,2,1,2,2v25.8h12.9v-29.1c0.2-12.1-7.1-21.6-18.7-21.6h-18.9H198.2z"
                  ></path> <circle cx="40.6" cy="155.3" r="16.8"></circle>
                  <path
                    d="M15.6,225.8V200c0-1.2,1-2,2-2c1.2,0,2,0.8,2,2v25.8h41.5V200c0-1.2,1-2,2-2c1.2,0,2,1,2,2v25.8h12.9v-29.1 c0.2-12.1-7.1-21.6-18.7-21.6H40.4H21.5c-11.5,0-18.7,9.5-18.7,21.4v29.3H15.6z"
                  ></path>
                  <path
                    d="M110.1,155.3c0,9.3,7.5,16.8,16.8,16.8c9.3,0,16.8-7.5,16.8-16.8c0-9.3-7.5-16.8-16.8-16.8 C117.6,138.5,110.1,146,110.1,155.3z"
                  ></path> <circle cx="62.1" cy="113.5" r="16.8"></circle>
                  <circle cx="107.5" cy="113.5" r="16.8"></circle>
                  <circle cx="171.5" cy="77.6" r="16.8"></circle>
                  <circle cx="83.1" cy="77.6" r="16.8"></circle>
                  <circle cx="128.4" cy="77.6" r="16.8"></circle>
                  <circle cx="84.9" cy="155.3" r="16.8"></circle>
                </g>
              </g></svg
            >
            <span>{prettyFormatNumber(media.ratingCount)}</span>
          </div>
        {/if}
      </div>
      <div class="flex items-center">
        {#if media.runtime}
          <div class="flex items-center pr-4">
            <svg
              fill="#ffffff"
              viewBox="0 0 32 32"
              width="30px"
              height="30px"
              class="pr-2"
              version="1.1"
              xmlns="http://www.w3.org/2000/svg"
              ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g
                id="SVGRepo_tracerCarrier"
                stroke-linecap="round"
                stroke-linejoin="round"
              ></g><g id="SVGRepo_iconCarrier">
                <path
                  d="M0 16q0-3.232 1.28-6.208t3.392-5.12 5.12-3.392 6.208-1.28q3.264 0 6.24 1.28t5.088 3.392 3.392 5.12 1.28 6.208q0 3.264-1.28 6.208t-3.392 5.12-5.12 3.424-6.208 1.248-6.208-1.248-5.12-3.424-3.392-5.12-1.28-6.208zM4 16q0 3.264 1.6 6.048t4.384 4.352 6.016 1.6 6.016-1.6 4.384-4.352 1.6-6.048-1.6-6.016-4.384-4.352-6.016-1.632-6.016 1.632-4.384 4.352-1.6 6.016zM14.016 16v-5.984q0-0.832 0.576-1.408t1.408-0.608 1.408 0.608 0.608 1.408v4h4q0.8 0 1.408 0.576t0.576 1.408-0.576 1.44-1.408 0.576h-6.016q-0.832 0-1.408-0.576t-0.576-1.44z"
                ></path>
              </g></svg
            >
            <span class="">{media.runtime}</span>
          </div>
        {/if}
        <div class="pr-4">
          {#if !media.isMovie && media.seasonsCount && media.episodeCount}
            <span
              >{media.seasonsCount} SN&nbsp•&nbsp{prettyFormatNumber(
                media.episodeCount,
              )} EP</span
            >
          {:else if media.seasonsCount}
            <span>{media.seasonsCount} SN</span>
          {:else if media.episodeCount}
            <span>{prettyFormatNumber(media.episodeCount)} EP</span>
          {/if}
        </div>
        <div>
          {#if media.isMovie}
            {#if media.releaseYear}
              <span>{media.releaseYear}</span>
            {/if}
          {:else if media.isOngoing}
            <span>{media.releaseYear} - Ongoing</span>
          {:else if media.releaseYear == media.endYear}
            <span>{media.releaseYear}</span>
          {:else}
            <span>{media.releaseYear} - {media.endYear}</span>
          {/if}
        </div>
      </div>
      <div class="pt-4 flex items-center">
        {#if media.type}
          <div class="flex items-center pr-4">
            <svg
              fill="#ffffff"
              class="pr-2"
              height="30px"
              width="30px"
              version="1.1"
              xmlns="http://www.w3.org/2000/svg"
              xmlns:xlink="http://www.w3.org/1999/xlink"
              viewBox="0 0 50 50"
              xml:space="preserve"
              ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g
                id="SVGRepo_tracerCarrier"
                stroke-linecap="round"
                stroke-linejoin="round"
              ></g><g id="SVGRepo_iconCarrier">
                <g id="Layer_1">
                  <path
                    d="M1,38h23v3H12v2h26v-2H26v-3h23V8H1V38z M3,10h44v26H3V10z"
                  ></path>
                </g> <g> </g>
              </g></svg
            >
            <span>{media.type}</span>
          </div>
        {/if}
        {#if media.genres}
          {#each media.genres as genre, idx}
            <span class="font-semibold"
              >{genre}{media.genres.length - 1 == idx ? "" : " •"}&nbsp</span
            >
          {/each}
        {/if}
      </div>
      <div class="pt-4">
        {#if media.productionStatus}
          <span class="font-bold p-2"
            >{media.productionStatus.toLocaleUpperCase()}</span
          >
        {/if}
      </div>
    </div>
  </div>
</div>
