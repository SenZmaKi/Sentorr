<script lang="ts">
  import PageWrapper from "../common/PageWrapper.svelte";
  import { Language } from "@ctrl/video-filename-parser";
  import {
    TorrentStreamsError,
    type TorrentFile,
    type TorrentStream,
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
    playbackRate,
    video,
    currentTime,
    buffered,
    paused,
    duration,
    resolution,
    videoHeight,
    videoWidth
  } from "./common/store";
  import Controls from "./controls/Controls.svelte";

  export let hidden: boolean;
  let blacklistedTorrents: TorrentFile[] = [];
  $: {
    $playerMedia;
    $playerEpisode;
  }

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
    const torrentFiles = await window.ipc.torrent.getTorrentFiles({
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
      (torrent) => torrent.isCompleteSeason,
    );
    const episodeFiles = torrentFiles.filter(
      (torrent) => !torrent.isCompleteSeason,
    );
    const torrentAndScore = [
      ...computeTorrentScores({
        torrents: seasonFiles,
        preferredResolution: $resolution,
      }),
      ...computeTorrentScores({
        torrents: episodeFiles,
        preferredResolution: $resolution,
      }),
    ];
    const sortedByScore = torrentAndScore.sort((a, b) => b.score - a.score);
    const torrentFile = sortedByScore[0].torrent;
    let torrentsStreams: TorrentStream[] = [];
    try {
      torrentsStreams = await window.ipc.torrent.getTorrentStreams(
        media.title,
        torrentFile,
        !media.isMovie,
      );
    } catch (error: any) {
      onTorrentStreamsError(error, torrentFile);
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
            torrStream.info.episodeNumber === episode.number &&
            torrStream.info.seasonNumber === episode.seasonNumber,
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
    console.log("streamURL:", torrentStream.url);
    await window.ipc.torrent.selectTorrentStream(torrentStream);
    $playerTorrentStream = torrentStream;
    $playerTorrentFile = torrentFile;
  }

  async function reload() {
    if (!$playerTorrentStream) return;
    window.ipc.torrent.selectTorrentStream($playerTorrentStream);
    $playerTorrentStream = $playerTorrentStream;
  }

  function onTorrentStreamsError(error: Error, torrentFile: TorrentFile) {
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

  function onPlaybackError() {
    if (!$video) return;
    const error = $video.error;
    if (!error) return;
    if (!$playerTorrentFile || !$playerTorrentStream) return;
    switch (error.code) {
      case error.MEDIA_ERR_SRC_NOT_SUPPORTED:
        blacklistedTorrents.push($playerTorrentFile);
        console.error(
          `Media codec error: Media at ${$playerTorrentStream.url} codec not supported (${JSON.stringify(error)}) `,
        );
        toast.error("Media codec error", {
          description:
            "The video or audio codec is unsupported. Dismiss this message to fetch a new torrent.",
          onDismiss: load,
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
        blacklistedTorrents.push($playerTorrentFile);
        console.error(
          `Media decode error: Media at ${$playerTorrentStream.url} decode error (${JSON.stringify(error)}) `,
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
    // DEBUG
    load();
  }
  function isValidCodecs() {
    if (!$video) return false;
    // We it's valid assume cause we don't have any information
    if (!$video.videoTracks || !$video.audioTracks || !$playerTorrentFile)
      return true;
    if (!$video.videoTracks.length && !$video.audioTracks.length) {
      blacklistedTorrents.push($playerTorrentFile);
      console.error("Media codec error: No video and audio tracks found");
      toast.error("Media codec error", {
        description:
          "The video and audio codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: load,
      });
    }
    if (!$video.videoTracks.length) {
      blacklistedTorrents.push($playerTorrentFile);
      console.error(`Video codec error: Video track not found`);
      toast.error("Video codec error", {
        description:
          "The video codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: load,
      });
      return false;
    }
    if (!$video.audioTracks.length) {
      blacklistedTorrents.push($playerTorrentFile);
      console.error(`Audio codec error: Audio track not found`);
      toast.error("Audio codec error", {
        description:
          "The audio codec is unsupported. Dismiss this message to fetch a new torrent.",
        onDismiss: load,
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
  // let videoUrl = `${webtorrentDir}\\Mr.Robot.Season.1-4.S01-04.COMPLETE.1080p.BluRay.WEB.10bit.DD5.1.x265-POIASD\\Mr.Robot.S01.1080p.BluRay.10bit.DD5.1.x265-POIASD\\Mr.Robot.S01E01.1080p.BluRay.10bit.DD5.1.x265-POIASD.mkv`;
  // let videorl = `${webtorrentDir}\\Mr.Robot.SEASON.01.S01.COMPLETE.1080p.10bit.BluRay.6CH.x265.HEVC-PSA\\Mr.Robot.S01E01.eps1.0_hellofriend.mov.1080p.10bit.BluRay.6CH.x265.HEVC-PSA.mkv`;
  // let videoUrl = `${webtorrentDir}\\Invincible (2021) Season 1 S01 (1080p WEB-DL x265 HEVC 10bit EAC3 5.1 SAMPA)\\Invincible (2021) - S01E01 - It's About Time (1080p WEB-DL x265 SAMPA).mkv`;
  // let  videoUrl = `${webtorrentDir}\\[SubsPlease] Solo Leveling - 14 (1080p) [2FD84CD9].mkv`;
  // let videoUrl =
  //   "https://github.com/user-attachments/assets/06fae060-0bc9-43b0-8153-04f4cf430e22";
</script>

<PageWrapper {hidden}>
  <div
    class="relative flex flex-col items-center justify-center bg-black w-full h-screen"
  >
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      crossorigin="anonymous"
      bind:muted={$muted}
      bind:volume={$volume}
      bind:playbackRate={$playbackRate}
      bind:currentTime={$currentTime}
      bind:buffered={$buffered}
      bind:paused={$paused}
      bind:duration={$duration}
      bind:this={$video}
      on:error={onPlaybackError}
      bind:videoWidth={$videoWidth}
      bind:videoHeight={$videoHeight}
      on:loadedmetadata={() => {
        if ($video && isValidCodecs()) $paused = false;
      }}
      src={$playerTorrentStream?.url}
    >
    </video>
    <div class="absolute bottom-[5%] w-full">
      <Controls />
    </div>
  </div>
</PageWrapper>
