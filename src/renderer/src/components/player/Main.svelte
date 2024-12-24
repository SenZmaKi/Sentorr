<script lang="ts">
  import { onMount } from "svelte";
  import media from "@/test-results/imdb/getMedia.json";
  import episodes from "@/test-results/imdb/getEpisodes.json";
  import PageWrapper from "../common/PageWrapper.svelte";
  import { getTorrentStreams, getTorrentFiles } from "$backend/torrent/api";
  import { Language } from "@ctrl/video-filename-parser";
  import { Resolution } from "$backend/torrent/common/types";
  import { computeTorrentScores } from "$backend/torrent/common/functions";

  export let hidden: boolean;
  let videoElement: HTMLVideoElement;
  const episode = episodes[0];

  onMount(async () => {
    const languages = [Language.English];
    const torrentFiles = await getTorrentFiles({ media, episode, languages });
    if (!torrentFiles.length) {
      console.error("No torrent files found");
      return;
    }
    const seasonFiles = torrentFiles.filter(
      (torrent) => torrent.isCompleteSeason
    );
    const episodeFiles = torrentFiles.filter(
      (torrent) => !torrent.isCompleteSeason
    );
    console.log("torrentFiles:", torrentFiles);
    console.log("seasonFiles", seasonFiles);
    console.log("episodeFiles", episodeFiles);
    const preferredResolution = Resolution.R720P;
    const torrentAndScore = [
      ...computeTorrentScores({
        torrents: seasonFiles,
        preferredResolution,
      }),
      ...computeTorrentScores({
        torrents: episodeFiles,
        preferredResolution,
      }),
    ];
    const sortedByScore = torrentAndScore.sort((a, b) => b.score - a.score);
    console.log("sortedByScore:", sortedByScore);
    const torrentFile = sortedByScore[0].torrent;
    const torrentsStreams = await getTorrentStreams(torrentFile);
    if (!torrentsStreams.length) {
      console.error("No torrent streams found");
      return;
    }
    console.log("torrentsStreams:", torrentsStreams);
    const torrentStream = !torrentFile.isCompleteSeason
      ? torrentsStreams[0]
      : torrentsStreams.find(
          (torrStream) =>
            torrStream.info &&
            torrStream.info.episodeNumber === episode.number &&
            torrStream.info.seasonNumber === episode.seasonNumber
        );
    if (!torrentStream) {
      console.error("No matching torrent stream found");
      return;
    }
    if (!torrentFile.isCompleteSeason && episode)
      torrentStream.info = {
        episodeNumber: episode.number,
        seasonNumber: episode.seasonNumber,
      };
    console.log("torrentStream:", torrentStream);
    console.log("streamURL:", torrentStream.url);
    videoElement.src = torrentStream.url;
  });
</script>

<PageWrapper {hidden}>
  <video class="w-full h-full" bind:this={videoElement} controls></video>
</PageWrapper>

<style>
</style>
