These synthetic fixtures contain a 16-second generated test pattern and sine
wave, H.264 with B-frames and a two-second GOP, and AAC audio. No external media.

Generate with FFmpeg:

```sh
ffmpeg -f lavfi -i testsrc2=size=160x90:rate=10:duration=16 \
  -f lavfi -i sine=frequency=440:duration=16 \
  -c:v libx264 -g 20 -keyint_min 20 -sc_threshold 0 -crf 32 \
  -c:a aac -b:a 24k index.mp4
ffmpeg -i index.mp4 -c copy index.mkv
ffprobe -v error -show_packets \
  -show_entries packet=stream_index,pts_time,duration_time,pos,size,flags \
  -of json index.mp4 > mp4_packets.json
```

Additional containers are derived from the same synthetic source:

```sh
ffmpeg -i index.mp4 -c copy index.mov
ffmpeg -i index.mp4 -c:v libvpx-vp9 -deadline realtime -cpu-used 8 \
  -g 24 -c:a libopus index.webm
ffmpeg -i index.mp4 -c:v mpeg4 -bf 0 -g 24 -c:a pcm_s16le index.avi
ffprobe -v error -show_packets \
  -show_entries packet=pts_time,duration_time,pos,size -of json \
  index.avi > avi_packets.json
```
