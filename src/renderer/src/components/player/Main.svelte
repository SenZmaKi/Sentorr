<script lang="ts">
  import PageWrapper from "../common/PageWrapper.svelte";
  import {
    getTorrentStreams,
    getTorrentFiles,
    getCurrentTorrentStreamStats,
  } from "@/backend/torrent/api";
  import { Language } from "@ctrl/video-filename-parser";
  import {
    Resolution,
    TorrentStreamsError,
    type TorrentFile,
    type TorrentStream,
    type TorrentStreamStats,
  } from "@/backend/torrent/common/types";
  import { computeTorrentScores } from "@/backend/torrent/common/functions";
  import { toast } from "svelte-sonner";
  import {
    playerMedia,
    playerEpisode,
    playerTorrentFile,
    playerTorrentStream,
  } from "./store";
  import { selectTorrentStream } from "@/backend/torrent/api";

  export let hidden: boolean;
  let blacklistedTorrents: TorrentFile[] = [];
  let torrentStreamStats: TorrentStreamStats | undefined = undefined;

  let video: HTMLMediaElement;

  async function load() {
    let media = $playerMedia;
    let episode = $playerEpisode;
    if (!media) {
      console.error("Media is not set");
      return;
    }
    if (!episode) {
      console.error("Episode is not set");
      return;
    }
    if (!media.title) {
      console.error(`Media ${media.id} has no title`);
      toast.error("No media title", {
        description: "The media has no title to use to fetch torrents.",
      });
      return;
    }
    const languages = [Language.English];
    const torrentFiles = await getTorrentFiles({
      media,
      episode,
      languages,
      blacklistedTorrents: blacklistedTorrents,
    });
    if (!torrentFiles.length) {
      console.error("No torrent files found");
      toast.error("No torrents found", {
        description: "No torrents were found for this media.",
      });
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
    let torrentsStreams: TorrentStream[] = [];
    try {
      torrentsStreams = await getTorrentStreams(
        media.title,
        torrentFile,
        !media.isMovie
      );
    } catch (error: any) {
      handleTorrentStreamsError(error, torrentFile);
      return;
    }

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
            episode &&
            torrStream.info.episodeNumber === episode.number &&
            torrStream.info.seasonNumber === episode.seasonNumber
        );
    if (!torrentStream) {
      console.error("No matching torrent stream found");
      return;
    }
    // We assume the episode and season are the one's we wanted
    if (!torrentFile.isCompleteSeason && episode)
      torrentStream.info = {
        episodeNumber: episode.number,
        seasonNumber: episode.seasonNumber,
      };
    console.log("torrentStream:", torrentStream);
    console.log("streamURL:", torrentStream.url);
    selectTorrentStream(torrentStream);
    $playerTorrentStream = torrentStream;
    $playerTorrentFile = torrentFile;
  }

  async function reload() {
    if (!$playerTorrentStream) return;
    selectTorrentStream($playerTorrentStream);
    $playerTorrentStream = $playerTorrentStream;
  }

  function handleTorrentStreamsError(error: Error, torrentFile: TorrentFile) {
    blacklistedTorrents.push(torrentFile);
    switch (error.message) {
      case TorrentStreamsError.TorrentTimeout:
        console.error(TorrentStreamsError.TorrentTimeout, torrentFile);
        toast.error(TorrentStreamsError.TorrentTimeout, {
          description:
            "The torrent timed out while being fetched. This is usually because the torrent is not available anymore. Dismiss this message to fetch a new torrent.",
          onDismiss: load,
        });
        break;
      case TorrentStreamsError.NoVideoFiles:
        console.error(TorrentStreamsError.TorrentTimeout, torrentFile);
        toast.error(TorrentStreamsError.NoVideoFiles, {
          description:
            "The torrent contains no video files. Dismiss this message to fetch a new torrent.",
          onDismiss: load,
        });
      case TorrentStreamsError.NoMatchingFiles:
        console.error(TorrentStreamsError.NoMatchingFiles, torrentFile);
        toast.error(TorrentStreamsError.NoMatchingFiles, {
          description:
            "The torrent does not contain files matching the media parameters. Dismiss this message to fetch a new torrent.",
          onDismiss: load,
        });
        break;
      default:
        throw error;
    }
  }

  function handlePlaybackError() {
    const error = video.error;
    if (!error) return;
    if (!$playerTorrentFile || !$playerTorrentStream) return;
    switch (error.code) {
      case error.MEDIA_ERR_SRC_NOT_SUPPORTED:
        blacklistedTorrents.push($playerTorrentFile);
        console.error(
          `Media codec error: Media at ${$playerTorrentStream.url} codec not supported (${JSON.stringify(error)}) `
        );
        toast.error("Unsupported media codec", {
          description:
            "The media codec is unsupported. Dismiss this message to fetch a new torrent.",
          onDismiss: load,
        });
        break;
      case error.MEDIA_ERR_NETWORK:
        console.error(
          `Network error: Failed to fetch media at ${$playerTorrentStream.url}`
        );
        toast.error("Network error", {
          description:
            "Failed to fetch media. Check your internet connection and try again. Dismiss this message to fetch reload.",
          onDismiss: reload,
        });
        break;

      case error.MEDIA_ERR_DECODE:
        blacklistedTorrents.push($playerTorrentFile);
        console.error(
          `Media decode error: Media at ${$playerTorrentStream.url} decode error (${JSON.stringify(error)}) `
        );
        toast.error("Media decoding error", {
          description:
            "Failed to decode media. Dismiss this message to fetch a new torrent.",
          onDismiss: load,
        });

      default:
        throw error;
    }
  }
  $: if ($playerMedia && $playerEpisode) {
    load();
  }
  function handleLoadedMetadata() {
    // @ts-ignore tracks are available when you run electron with following set
    // webPreferences.enableBlinkFeatures = "FontAccess, AudioVideoTracks"
    if (!video.videoTracks || !video.audioTracks || !$playerTorrentFile) return;

    // @ts-ignore
    if (!video.videoTracks.length && !video.audioTracks.length) {
      blacklistedTorrents.push($playerTorrentFile);
      console.error("Media codec error: No video and audio tracks found");
      toast.error("Media codec error", {
        description:
          "The media codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: load,
      });
    }
    // @ts-ignore
    if (!video.videoTracks.length) {
      blacklistedTorrents.push($playerTorrentFile);
      console.error(`Video codec error: Video track not found`);
      toast.error("Video codec error", {
        description:
          "The video codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: load,
      });
      return;
    }
    // @ts-ignore
    if (!video.audioTracks.length) {
      blacklistedTorrents.push($playerTorrentFile);
      console.error(`Audio codec error: Audio track not found`);
      toast.error("Audio codec error", {
        description:
          "The audio codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: load,
      });
      return;
    }
  }
  setInterval(async () => {
    if (!$playerMedia || !$playerTorrentStream || !$playerTorrentFile) return;
    torrentStreamStats = await getCurrentTorrentStreamStats();
    // console.log(`torrentStreamStats: ${JSON.stringify(torrentStreamStats)}`);
  }, 1_000);
</script>

<PageWrapper {hidden}>
  <video
    class="w-full h-full"
    bind:this={video}
    controls
    on:error={handlePlaybackError}
    src={$playerTorrentStream?.url}
    on:loadedmetadata={handleLoadedMetadata}
  >
  </video>
</PageWrapper>

<style>
</style>
