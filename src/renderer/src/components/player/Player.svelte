<script lang="ts">
  import PageWrapper from "../common/PageWrapper.svelte";
  import {
    Resolution,
    GetTorrentStreamsError,
    type TorrentFile,
    SelectTorrentStreamError,
  } from "@/backend/torrent/common/types";
  import { computeTorrentScores } from "@/backend/torrent/common/functions";
  import { toast } from "svelte-sonner";
  import {
    playerMedia,
    playerEpisode,
    playerTorrentFile,
    playerTorrentStream,
    muted,
    volume,
    ended,
    playbackRate,
    video,
    videoContainer,
    currentTime,
    buffered,
    paused,
    duration,
    resolution,
    videoHeight,
    videoWidth,
    blacklistedTorrents,
    languages,
    showControls,
    strictResolution,
  } from "./common/store";
  import Controls from "./controls/Controls.svelte";
  import { getCurrentMediaProgress } from "../common/store";
  import { tryCatchAsync } from "@/common/functions";
  import type { Episode, Media } from "@/backend/imdb/types";
  import type { Language } from "@ctrl/video-filename-parser";

  export let hidden: boolean;

  async function clearVideo() {
    if (!$video) return;
    $playerTorrentStream = undefined;
    $playerTorrentFile = undefined;
    await window.ipc.torrent.deselectAllTorrentStreams();
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
    if (!media.title) {
      console.error(`Media ${media.id} has no title`);
      toast.error("No media title", {
        description: "The media has no title to use to fetch torrents.",
      });
      return;
    }
    const torrentFiles = await window.ipc.torrent.getTorrentFiles({
      media,
      episode,
      languages,
      blacklistedTorrents: $blacklistedTorrents,
    });
    // load() was called later and it resolved faster than the current call
    if ($playerTorrentStream && $playerTorrentFile) return;
    const resTorrentFiles = strictResolution
      ? torrentFiles.filter((torrent) => torrent.resolution === resolution)
      : torrentFiles;
    if (!resTorrentFiles.length) {
      console.error("No torrent files found: ", media);
      toast.error("No torrents found", {
        description: torrentFiles.length
          ? `No ${resolution}p torrents found. Try disabling "strict resolution".`
          : "No torrents were found for this media.",
      });
      return;
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
    const torrentFile = sortedByScore[0].torrent;
    const [torrentsStreams, torrentStreamsError] = await tryCatchAsync(
      window.ipc.torrent.getTorrentStreams(
        media.title,
        torrentFile,
        !media.isMovie,
      ),
    );
    if (torrentStreamsError) {
      onGetTorrentStreamsError(torrentStreamsError, torrentFile);
      return;
    }
    if (!torrentsStreams.length) {
      console.error("No torrent streams found");
      return;
    }
    const torrentStream = !torrentFile.isCompleteSeason
      ? torrentsStreams[0]
      : torrentsStreams.find(
          (torrStream) =>
            torrStream.info &&
            episode &&
            torrStream.info.episodeNumber ===
              episode.seasonEpisode.episodeNumber &&
            torrStream.info.seasonNumber === episode.seasonEpisode.seasonNumber,
        );
    if (!torrentStream) {
      console.error("No matching torrent stream found");
      return;
    }
    // We assume the episode and season are the one's we wanted
    if (!torrentFile.isCompleteSeason && episode)
      torrentStream.info = {
        episodeNumber: episode.seasonEpisode.episodeNumber,
        seasonNumber: episode.seasonEpisode.seasonNumber,
      };
    console.log("streamURL:", torrentStream.url);
    const [, stsError] = await tryCatchAsync(
      window.ipc.torrent.selectTorrentStream(torrentStream),
    );
    if (stsError) {
      if (stsError.message === SelectTorrentStreamError.StreamNotFound) {
        console.error(SelectTorrentStreamError.StreamNotFound, torrentStream);
        toast.error(SelectTorrentStreamError.StreamNotFound, {
          description:
            "😖 app in invalid state!!! Dismiss this message to reload the torrent.",
          onDismiss: reload,
        });
      }
    }
    $playerTorrentStream = torrentStream;
    $playerTorrentFile = torrentFile;
  }

  async function reload() {
    if (!$playerTorrentStream) return;
    window.ipc.torrent.selectTorrentStream($playerTorrentStream);
    $playerTorrentStream = { ...$playerTorrentStream };
  }
  async function maybeLoad() {
    loadParams && (await load(loadParams));
  }

  function onGetTorrentStreamsError(error: Error, torrentFile: TorrentFile) {
    $blacklistedTorrents = [...$blacklistedTorrents, torrentFile];

    switch (error.message) {
      case GetTorrentStreamsError.TorrentTimeout:
        console.error(GetTorrentStreamsError.TorrentTimeout, torrentFile);
        toast.error(GetTorrentStreamsError.TorrentTimeout, {
          description:
            "The torrent timed out while being fetched, usually because it has no peers. Dismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      case GetTorrentStreamsError.NoVideoFiles:
        console.error(GetTorrentStreamsError.NoVideoFiles, torrentFile);
        toast.error(GetTorrentStreamsError.NoVideoFiles, {
          description:
            "The torrent contains no video files. Dismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
      case GetTorrentStreamsError.NoMatchingFiles:
        console.error(GetTorrentStreamsError.NoMatchingFiles, torrentFile);
        toast.error(GetTorrentStreamsError.NoMatchingFiles, {
          description:
            "The torrent does not contain files matching the media parameters. Dismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      default:
        throw error;
    }
  }

  function onPlaybackError() {
    if (!$video) return;
    const error = $video.error;
    if (!error) return;
    if (!$playerTorrentFile || !$playerTorrentStream) return;
    switch (error.code) {
      case error.MEDIA_ERR_SRC_NOT_SUPPORTED:
        $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
        console.error(
          `Media codec error: Media at ${$playerTorrentStream.url} codec not supported (${JSON.stringify(error)}) `,
        );
        toast.error("Media codec error", {
          description:
            "The video or audio codec is unsupported. Dismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });
        break;
      case error.MEDIA_ERR_NETWORK:
        console.error(
          `Network error: Failed to fetch media at ${$playerTorrentStream.url}`,
        );
        toast.error("Network error", {
          description:
            "Failed to fetch media. Check your internet connection and try again. Dismiss this message to fetch reload.",
          onDismiss: reload,
        });
        break;

      case error.MEDIA_ERR_DECODE:
        $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
        console.error(
          `Media decode error: Media at ${$playerTorrentStream.url} decode error (${JSON.stringify(error)}) `,
        );
        toast.error("Media decoding error", {
          description:
            "Failed to decode media. Dismiss this message to fetch a new torrent.",
          onDismiss: maybeLoad,
        });

      default:
        throw error;
    }
  }

  function isValidCodecs() {
    if (!$video) return false;
    // We it's valid assume cause we don't have any information
    if (!$video.videoTracks || !$video.audioTracks || !$playerTorrentFile)
      return true;
    if (!$video.videoTracks.length && !$video.audioTracks.length) {
      $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
      console.error("Media codec error: No video and audio tracks found");
      toast.error("Media codec error", {
        description:
          "The video and audio codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: maybeLoad,
      });
    }
    if (!$video.videoTracks.length) {
      $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
      console.error(`Video codec error: Video track not found`);
      toast.error("Video codec error", {
        description:
          "The video codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: maybeLoad,
      });
      return false;
    }
    if (!$video.audioTracks.length) {
      $blacklistedTorrents = [...$blacklistedTorrents, $playerTorrentFile];
      console.error(`Audio codec error: Audio track not found`);
      toast.error("Audio codec error", {
        description:
          "The audio codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: maybeLoad,
      });
      return false;
    }
    return true;
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
  $: videoSrc = $playerTorrentStream?.url ?? "";
  $: loadParams = $playerMedia && {
    media: $playerMedia,
    episode: $playerEpisode,
    languages: $languages,
    resolution: $resolution,
    strictResolution: $strictResolution,
  };
  $: if (loadParams) load(loadParams);
</script>

<PageWrapper {hidden}>
  <div
    bind:this={$videoContainer}
    class:cursor-none={!$showControls}
    class="relative flex flex-col items-center justify-center bg-black w-full h-screen"
  >
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      crossorigin="anonymous"
      bind:muted={$muted}
      bind:volume={$volume}
      bind:playbackRate={$playbackRate}
      bind:ended={$ended}
      bind:currentTime={$currentTime}
      bind:buffered={$buffered}
      bind:paused={$paused}
      bind:duration={$duration}
      bind:this={$video}
      on:error={onPlaybackError}
      bind:videoWidth={$videoWidth}
      bind:videoHeight={$videoHeight}
      on:loadedmetadata={async () => {
        if (!$video || !isValidCodecs()) return;
        const currentMediaProgress = getCurrentMediaProgress();
        if (currentMediaProgress) {
          $currentTime = currentMediaProgress.time;
        }
        await $video.play();
      }}
      src={videoSrc}
    >
    </video>
    <div class="absolute bottom-[5%] w-full">
      <Controls />
    </div>
  </div>
</PageWrapper>
