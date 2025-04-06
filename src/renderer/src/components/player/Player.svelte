<script lang="ts">
  import PageWrapper from "../common/PageWrapper.svelte";
  import {
    Resolution,
    type TorrentFile,
  } from "@/backend/torrent/sources/common/types";
  import {
    GetTorrentStreamError,
    SelectTorrentStreamError,
  } from "@/backend/torrent/server/common/types";
  import { computeTorrentScores } from "@/backend/torrent/sources/common/functions";
  import { toast } from "svelte-sonner";
  import {
    playerMedia,
    playerEpisode,
    playerTorrentFile,
    playerTorrentStream,
    video,
    videoContainer,
    src,
    resolution,
    blacklistedTorrents,
    languages,
    showControls,
    strictResolution,
    waiting,
  } from "./common/store";
  import { config } from "../common/store";
  import Controls from "./controls/Controls.svelte";
  import { getMediaProgress } from "../common/store";
  import { tryCatchAsync } from "@/common/functions";
  import type { Episode, Media, SeasonEpisode } from "@/backend/imdb/types";
  import type { Language } from "@ctrl/video-filename-parser";
  import Video from "./Video.svelte";
  import { Page } from "../common/types";
  import { fade } from "svelte/transition";
  import Spinner from "../common/Spinner.svelte";

  async function clearVideo() {
    if (!$video) return;
    $playerTorrentStream = undefined;
    $playerTorrentFile = undefined;
    await window.ipc.torrentServer.deselectAllTorrentStreams();
  }

  async function getBestTorrentFile({
    media,
    episode,
    languages,
    resolution,
    strictResolution,
  }: {
    media: Media;
    episode: Episode | undefined;
    languages: Language[];
    resolution: Resolution;
    strictResolution: boolean;
  }) {
    if (!media.title) {
      console.error(`Media ${media.id} has no title`);
      toast.error("No media title", {
        description: "The media has no title to use to fetch torrents.",
      });
      return undefined;
    }
    const torrentFiles = await window.ipc.torrentServer.getTorrentFiles({
      title: media.title,
      mediaImdbID: media.id,
      episodeImdbID: episode?.id,
      seasonEpisode: episode?.seasonEpisode,
      languages,
      blacklistedTorrents: $blacklistedTorrents,
    });
    console.log("torrentFiles:", torrentFiles);
    // load() was called later and it resolved faster than the current call
    if ($playerTorrentStream && $playerTorrentFile) return undefined;
    const resTorrentFiles = strictResolution
      ? torrentFiles.filter((torrent) => torrent.resolution === resolution)
      : torrentFiles;
    if (!resTorrentFiles.length) {
      console.error("No torrent files found: ", media);
      toast.error("No torrents found", {
        description: strictResolution
          ? `No ${resolution}p torrents found. Try disabling "strict resolution".`
          : "No torrents were found for this media.",
      });
      return undefined;
    }
    const seasonFiles = resTorrentFiles.filter(
      (torrent) => torrent.isCompleteSeason,
    );
    const episodeFiles = resTorrentFiles.filter(
      (torrent) => !torrent.isCompleteSeason,
    );
    const torrentAndScore = [
      ...computeTorrentScores({
        torrents: seasonFiles,
        preferredResolution: resolution,
      }),
      ...computeTorrentScores({
        torrents: episodeFiles,
        preferredResolution: resolution,
      }),
    ];
    const sortedByScore = torrentAndScore.sort((a, b) => b.score - a.score);
    const { torrent, score } = sortedByScore[0];
    console.log("Best torrent file:", torrent, "with score:", score);
    return torrent;
  }

  async function streamTorrent(
    {
      title,
      seasonEpisode,
      torrentFile,
    }: {
      title: string;
      seasonEpisode: SeasonEpisode | undefined;
      torrentFile: TorrentFile;
    },
    attempt = 0,
  ) {
    const [torrentStream, getError] = await tryCatchAsync(
      window.ipc.torrentServer.getTorrentStream(
        title,
        torrentFile,
        seasonEpisode,
      ),
    );
    if (getError) {
      const maxRetries = $config.torrent.torrentTimeoutRetries;
      if (
        getError.message === GetTorrentStreamError.TorrentTimeout &&
        attempt < maxRetries
      ) {
        const nextAttempt = attempt + 1;
        toast.error(GetTorrentStreamError.TorrentTimeout, {
          description: `Torrent timed out while being fetched. Retrying ${nextAttempt}/${maxRetries} times...`,
        });
        return streamTorrent(
          {
            title,
            seasonEpisode,
            torrentFile,
          },
          nextAttempt,
        );
      }
      onGetTorrentStreamError(getError, torrentFile);
      return;
    }
    if (attempt)
      toast.success("Torrent fetched successfully", {
        description: `Fetched after ${attempt} ${attempt === 1 ? "retry" : "retries"}.`,
      });

    console.log("torrentStream", torrentStream);
    const [, selectError] = await tryCatchAsync(
      window.ipc.torrentServer.selectTorrentStream(torrentStream),
    );
    if (selectError) {
      if (selectError.message === SelectTorrentStreamError.StreamNotFound) {
        console.error(SelectTorrentStreamError.StreamNotFound, torrentStream);
        toast.error(SelectTorrentStreamError.StreamNotFound, {
          description:
            "😖 app in invalid state!!!\nDismiss this message to reload the torrent.",
          onDismiss: reload,
        });
      } else throw selectError;
    }
    $playerTorrentStream = torrentStream;
    $playerTorrentFile = torrentFile;
  }

  async function load(params: {
    media: Media;
    episode: Episode | undefined;
    languages: Language[];
    resolution: Resolution;
    strictResolution: boolean;
  }) {
    const { media, episode, languages, resolution, strictResolution } = params;
    console.log("load()", params);
    await clearVideo();
    const torrentFile = await getBestTorrentFile({
      media,
      episode,
      languages,
      resolution,
      strictResolution,
    });
    if (!torrentFile) return;
    if (!media.title) return;
    streamTorrent({
      title: media.title,
      seasonEpisode: episode?.seasonEpisode,
      torrentFile,
    });
  }

  async function reload() {
    if (!$playerTorrentStream) return;
    window.ipc.torrentServer.selectTorrentStream($playerTorrentStream);
    $playerTorrentStream = { ...$playerTorrentStream };
  }
  async function maybeLoad() {
    loadParams && (await load(loadParams));
  }

  function onGetTorrentStreamError(error: Error, torrentFile: TorrentFile) {
    console.error("onGetTorrentStreamError()", error, torrentFile);
    $blacklistedTorrents = [...$blacklistedTorrents, torrentFile];

    switch (error.message) {
      case GetTorrentStreamError.TorrentTimeout:
        console.error(GetTorrentStreamError.TorrentTimeout, torrentFile);
        toast.error(GetTorrentStreamError.TorrentTimeout, {
          description:
            "The torrent timed out while being fetched, usually because it has no peers.\nDismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      case GetTorrentStreamError.NoMatchingFile:
        console.error(GetTorrentStreamError.NoMatchingFile, torrentFile);
        toast.error(GetTorrentStreamError.NoMatchingFile, {
          description:
            "The torrent does not contain files matching the media.\nDismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      default:
        throw error;
    }
  }

  function onVideoError(error: MediaError) {
    if (!$playerTorrentFile || !$playerTorrentStream) return;
    switch (error.code) {
      case error.MEDIA_ERR_SRC_NOT_SUPPORTED:
        $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
        console.error(
          `Media codec error: Media at ${$playerTorrentStream.url} codec not supported`,
          error,
        );
        toast.error("Media codec error", {
          description:
            "The video or audio codec is unsupported.\nDismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      case error.MEDIA_ERR_NETWORK:
        console.error(
          `Network error: Failed to fetch media at ${$playerTorrentStream.url}`,
        );
        toast.error("Network error", {
          description:
            "Failed to fetch media. Check your internet connection and try again.\nDismiss this message to fetch reload.",
          onDismiss: reload,
        });
        break;

      case error.MEDIA_ERR_DECODE:
        $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
        console.error(
          `Media decode error: Media at ${$playerTorrentStream.url} decode error`,
          error,
        );
        toast.error("Media decoding error", {
          description:
            "Failed to decode media.\nDismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      default:
        throw error;
    }
  }

  function hasValidCodecs() {
    if (!$video) return false;
    // We assume it's valid cause we don't have enough information
    if (!$video.videoTracks || !$video.audioTracks || !$playerTorrentFile)
      return true;

    function blacklistCurrentTorrent() {
      if (!$playerTorrentFile) return;
      $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
    }

    if (!$video.videoTracks.length && !$video.audioTracks.length) {
      blacklistCurrentTorrent();
      console.error("Media codec error: No video and audio tracks found");
      toast.error("Media codec error", {
        description:
          "The video and audio codec are unsupported.\nDismiss this message to fetch a new torrent.",
        onDismiss: maybeLoad,
      });
      return false;
    }

    if (!$video.videoTracks.length) {
      blacklistCurrentTorrent();
      console.error(`Video codec error: Video track not found`);
      toast.error("Video codec error", {
        description:
          "The video codec is unsupported.\nDismiss this message to fetch a new torrent.",
        onDismiss: maybeLoad,
      });
      return false;
    }

    if (!$video.audioTracks.length) {
      blacklistCurrentTorrent();
      console.error(`Audio codec error: Audio track not found`);
      toast.error("Audio codec error", {
        description:
          "The audio codec is unsupported.\nDismiss this message to fetch a new torrent.",
        onDismiss: maybeLoad,
      });
      return false;
    }
    return true;
  }
  async function onLoadedMetadata() {
    if (!$video || !hasValidCodecs()) return;
    if ($playerMedia) {
      const currentMediaProgress = getMediaProgress($playerMedia.id);
      if (
        currentMediaProgress &&
        currentMediaProgress.episode?.id === $playerEpisode?.id
      ) {
        const currentTime =
          currentMediaProgress.watchTime.currentTime -
          $config.player.continueRewindSecs;
        if (currentTime <= 0) return;
        $video.currentTime = currentTime;
      }
    }
    await $video.play();
  }

  // setInterval(async () => {
  //   if (!$playerMedia || !$playerTorrentStream || !$playerTorrentFile) return;
  //   const torrentStreamStats =
  //     await window.ipc.torrent.getCurrentTorrentStreamStats();
  //   // console.log(`torrentStreamStats: ${JSON.stringify(torrentStreamStats)}`);
  // }, 1_000);
  // const webtorrentDir = "file:C:\\Users\\Sen\\AppData\\Local\\Temp\\webtorrent";
  // let videoSrc = `${webtorrentDir}\\Mr.Robot.Season.1-4.S01-04.COMPLETE.1080p.BluRay.WEB.10bit.DD5.1.x265-POIASD\\Mr.Robot.S01.1080p.BluRay.10bit.DD5.1.x265-POIASD\\Mr.Robot.S01E01.1080p.BluRay.10bit.DD5.1.x265-POIASD.mkv`;
  // let videoSrc = `${webtorrentDir}\\Mr.Robot.SEASON.01.S01.COMPLETE.1080p.10bit.BluRay.6CH.x265.HEVC-PSA\\Mr.Robot.S01E01.eps1.0_hellofriend.mov.1080p.10bit.BluRay.6CH.x265.HEVC-PSA.mkv`;
  // let videoSrc = `${webtorrentDir}\\Invincible (2021) Season 1 S01 (1080p WEB-DL x265 HEVC 10bit EAC3 5.1 SAMPA)\\Invincible (2021) - S01E01 - It's About Time (1080p WEB-DL x265 SAMPA).mkv`;
  // let  videoSrc = `${webtorrentDir}\\[SubsPlease] Solo Leveling - 14 (1080p) [2FD84CD9].mkv`;
  // let videoSrc =
  //   "https://github.com/user-attachments/assets/06fae060-0bc9-43b0-8153-04f4cf430e22";

  $: loadParams = $playerMedia && {
    media: $playerMedia,
    episode: $playerEpisode,
    languages: $languages,
    resolution: $resolution,
    strictResolution: $strictResolution,
  };
  $: console.log("episode and media:", $playerEpisode, $playerMedia);
  $: if (loadParams) load(loadParams);
  $: $src = $playerTorrentStream?.url ?? "";

  window.ipc.torrentServer.start($config.torrent);
  setInterval(() => {
    return;
    //  TODO: Add types for this
    // @ts-ignore
    const memory = performance.memory;
    console.log(
      `Used Memory: ${(memory.usedJSHeapSize / 1024 / 1024).toFixed(2)} MB`,
    );
    console.log(
      `Total Memory: ${(memory.totalJSHeapSize / 1024 / 1024).toFixed(2)} MB`,
    );
    console.log(
      `Memory Limit: ${(memory.jsHeapSizeLimit / 1024 / 1024 / 1024).toFixed(2)} GB`,
    );
  }, 1_000);
</script>

<PageWrapper page={Page.Player}>
  <div
    bind:this={$videoContainer}
    class:cursor-none={!$showControls}
    class="relative flex flex-col items-center justify-center bg-black w-full h-screen"
  >
    {#if $waiting}
      <div
        transition:fade
        class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
      >
        <Spinner class="w-16 h-16 fill-[#f00] " />
      </div>
    {/if}
    <Video onError={onVideoError} {onLoadedMetadata} />

    <div class="absolute bottom-[0%] w-full">
      <Controls />
    </div>
  </div>
</PageWrapper>
