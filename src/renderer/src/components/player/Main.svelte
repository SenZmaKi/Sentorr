<script lang="ts">
  import { onMount } from "svelte";
  import media from "@/test-results/getMedia.json";
  import episodes from "@/test-results/getEpisodes.json";
  import PageWrapper from "../common/PageWrapper.svelte";
  import { getTorrentStreams, getTorrentFiles } from "$backend/torrent/api";
  import { Language, Resolution } from "@ctrl/video-filename-parser";
  export let hidden: boolean;
  let videoElement: HTMLVideoElement;
  const episode = episodes[0];

  function resToInt(res: Resolution): number {
    switch (res) {
      case Resolution.R2160P:
        return 2160;
      case Resolution.R1080P:
        return 1080;
      case Resolution.R720P:
        return 720;
      case Resolution.R576P:
        return 576;
      case Resolution.R540P:
        return 540;
      case Resolution.R480P:
        return 480;
    }
  }

  onMount(async () => {
    const languages = [Language.English];
    const torrentFiles = await getTorrentFiles({ media, episode, languages });
    if (!torrentFiles.length) {
      console.error("No torrent files found");
      return;
    }
    console.log("torrentFiles:", torrentFiles);
    const sortedByRes = torrentFiles.sort(
      (a, b) => resToInt(b.resolution) - resToInt(a.resolution)
    );
    const preferredResolution: Resolution | undefined = Resolution.R1080P;
    const torrentFile = preferredResolution
      ? sortedByRes.find(
          (torrent) => torrent.resolution <= preferredResolution
        ) ?? sortedByRes[sortedByRes.length - 1]
      : torrentFiles.sort((a, b) => b.seeders - a.seeders)[0];
    console.log("torrentFile:", torrentFile);
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
