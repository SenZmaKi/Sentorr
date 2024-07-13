<script lang="ts">
  import type { Media, Episode } from "$backend/imdb/types";
  import { getSeriesTorrents } from "$backend/torrent/rargb/api";
  import { getTorrentsFiles as getMovieTorrents } from "$backend/torrent/yts/api";
  import { onMount } from "svelte";
  import media from "@/test-results/getMedia.json";
  import episodes from "@/test-results/getEpisodes.json";
  import WebTorrent from "webtorrent";
  import PageWrapper from "../common/PageWrapper.svelte";

  const episode = episodes[0];
  export let hidden: boolean;
  const client = new WebTorrent({ tracker: { port: 8080 } });
  // export let media: Media;
  // export let episode: Episode | undefined;
  let videoElement: HTMLVideoElement;
  onMount(async () => {
    if (!media.title || !episode?.seasonNumber) return;
    // const torrents = media.isMovie
    //   ? await getMovieTorrents(media.id)
    //   : await getSeriesTorrents(
    //       media.title,
    //       episode.seasonNumber,
    //       episode?.number
    //     );
    // const torrent = torrents[0];
    // console.log(torrent);
    client.add(
      "magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10&dn=Sintel&tr=udp%3A%2F%2Fexplodie.org%3A6969&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&tr=udp%3A%2F%2Ftracker.empire-js.us%3A1337&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=wss%3A%2F%2Ftracker.btorrent.xyz&tr=wss%3A%2F%2Ftracker.fastcast.nz&tr=wss%3A%2F%2Ftracker.openwebtorrent.com&ws=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2F&xs=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2Fsintel.torrent",
      (torrent) => {
        console.log("Torrent added");
        const file = torrent.files.find((file) => file.name.endsWith(".mp4"));
        if (!file) return;
        file.renderTo(videoElement);
        console.log("Rendered");
      }
    );
  });
</script>

<PageWrapper {hidden}>
  <div>Hey</div>
  <video bind:this={videoElement} controls />
</PageWrapper>

<style>
</style>
