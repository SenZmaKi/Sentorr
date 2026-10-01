"""Download open test clips and generate reproducible codec/track fixtures."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'assets' / 'media'
MEDIA.mkdir(parents=True, exist_ok=True)

def run(args):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr[-4000:])
    return result.stdout

def download(codec, extension):
    url = f'https://test-videos.co.uk/vids/bigbuckbunny/{extension}/{codec}/1080/Big_Buck_Bunny_1080_10s_5MB.{extension}'
    target = MEDIA / f'bbb_{codec}.{extension}'
    if not target.exists():
        print(f'Downloading {codec}', flush=True)
        run(['curl', '-L', '--fail', '--retry', '2', '-A', 'Mozilla/5.0', '-o', str(target), url])
    return target, url

entries = []
def add(path, title, purpose, source):
    probe = json.loads(run(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)]))
    entries.append(dict(file=path.name, title=title, purpose=purpose, source=source,
                        streams=probe['streams'], duration=probe['format'].get('duration'),
                        bytes=path.stat().st_size))

for codec, ext, title in [('h264','mp4','H.264 · MP4'), ('h265','mp4','HEVC · MP4'), ('av1','mp4','AV1 · MP4'), ('vp9','webm','VP9 · WebM')]:
    path, url = download(codec, ext)
    add(path, title, 'Downloaded 1080p motion sample; inspect actual stream details below.', url)

(MEDIA / 'captions.srt').write_text('1\n00:00:00,000 --> 00:00:04,000\nSRT subtitle: white text, first four seconds.\n\n2\n00:00:04,000 --> 00:00:09,900\nSRT subtitle: seek here and check synchronization.\n', encoding='utf-8')
(MEDIA / 'styled.ass').write_text('''[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,42,&H0000FFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,1,2,20,20,45,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:04.00,Default,,0,0,0,,ASS subtitle: yellow and bold
Dialogue: 0,0:00:04.00,0:00:09.90,Default,,0,0,0,,{\\i1}ASS subtitle: italic, check styling{\\i0}
''', encoding='utf-8')

base = MEDIA / 'bbb_h264.mp4'
cases = [
    ('hevc_main10.mkv', 'HEVC Main10 · AAC · MKV', ['-c:v','libx265','-preset','ultrafast','-pix_fmt','yuv420p10le','-crf','28'], 'aac', '10-bit SDR decoding; not an HDR validation clip.'),
    ('h264_hi10p.mkv', 'H.264 Hi10P · FLAC · MKV', ['-c:v','libx264','-preset','ultrafast','-pix_fmt','yuv420p10le','-crf','24'], 'flac', 'Anime-style 10-bit H.264 profile; may require software decoding.'),
    ('ac3_51.mkv', 'H.264 · AC-3 5.1 · MKV', ['-c:v','copy'], 'ac3', 'Six distinct test-tone channels; tests decoding/downmix, not passthrough.'),
    ('eac3_51.mkv', 'H.264 · E-AC-3 5.1 · MKV', ['-c:v','copy'], 'eac3', 'Six-channel Dolby Digital Plus decode/downmix.'),
    ('dts_51.mkv', 'H.264 · DTS 5.1 · MKV', ['-c:v','copy'], 'dca', 'Six-channel DTS core decode/downmix; not DTS-HD MA.'),
    ('truehd_51.mkv', 'H.264 · TrueHD 5.1 · MKV', ['-c:v','copy'], 'truehd', 'TrueHD decode/downmix; not an Atmos or passthrough test.'),
    ('opus.mkv', 'H.264 · Opus · MKV', ['-c:v','copy'], 'libopus', 'Opus audio in Matroska.'),
]
for name, title, video, audio, purpose in cases:
    output = MEDIA / name
    if not output.exists():
        print(f'Generating {name}', flush=True)
        channels = '5.1' if '51' in name else 'stereo'
        signal = 'aevalsrc=0.08*sin(2*PI*220*t)|0.08*sin(2*PI*330*t)|0.08*sin(2*PI*440*t)|0.08*sin(2*PI*80*t)|0.08*sin(2*PI*550*t)|0.08*sin(2*PI*660*t):s=48000:c=5.1' if channels == '5.1' else 'sine=frequency=440:sample_rate=48000'
        run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(base),'-f','lavfi','-i',signal,'-map','0:v:0','-map','1:a:0','-t','10',*video,'-c:a',audio,'-strict','-2','-ac','6' if channels == '5.1' else '2', str(output)])
    add(output,title,purpose,'Locally transcoded open Big Buck Bunny clip with generated audio; tools/prepare_samples.py')

output = MEDIA / 'tracks_subtitles.mkv'
if not output.exists():
    print('Generating multiple audio/subtitle tracks', flush=True)
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(base),'-f','lavfi','-i','sine=frequency=440:sample_rate=48000','-f','lavfi','-i','sine=frequency=880:sample_rate=48000','-i',str(MEDIA/'captions.srt'),'-i',str(MEDIA/'styled.ass'),'-map','0:v','-map','1:a','-map','2:a','-map','3:s','-map','4:s','-t','10','-c:v','copy','-c:a','aac','-c:s','copy','-metadata:s:a:0','title=Low tone 440 Hz','-metadata:s:a:1','title=High tone 880 Hz','-metadata:s:s:0','title=Plain SRT','-metadata:s:s:1','title=Styled ASS',str(output)])
add(output,'Track switching · AAC ×2 · SRT + ASS','Switch tones and subtitle tracks; compare styled ASS with plain SRT.','Locally remuxed open clip and generated test tracks')

output = MEDIA / 'hevc_4k60.mkv'
if not output.exists():
    print('Generating synthetic 4K60 HEVC Main10 stress clip', flush=True)
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','lavfi','-i','testsrc2=size=3840x2160:rate=60','-t','6','-c:v','libx265','-preset','ultrafast','-pix_fmt','yuv420p10le','-crf','30','-an',str(output)])
add(output,'4K60 · HEVC Main10 · synthetic','Stress test; SDR pattern and no audio, not a representative movie bitrate or HDR test.','Generated FFmpeg testsrc2 pattern')
(ROOT/'assets'/'samples.json').write_text(json.dumps(entries,indent=2),encoding='utf-8')
print(f'Prepared and ffprobe-verified {len(entries)} clips ({sum(e["bytes"] for e in entries)/1e6:.1f} MB)',flush=True)
