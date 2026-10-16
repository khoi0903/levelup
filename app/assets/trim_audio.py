"""Chạy sau generate_audio.py: cắt khoảng lặng đầu/cuối mọi clip và ghép sẵn số 11..99 thành 1 file.

Cần: pip install imageio-ffmpeg. Chạy: python assets/trim_audio.py assets/audio
"""
import os, shutil, subprocess, sys, tempfile
import imageio_ffmpeg
FF = imageio_ffmpeg.get_ffmpeg_exe()
ROOT = sys.argv[1]  # app/assets/audio

def trim_filter(tail):
    return (f'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,'
            f'areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence={tail},areverse')

def run(args):
    r = subprocess.run([FF, '-hide_banner', '-loglevel', 'error', '-y'] + args, capture_output=True, text=True)
    if r.returncode: raise SystemExit(r.stderr)

ENC = ['-ac', '1', '-ar', '24000', '-c:a', 'libmp3lame', '-b:a', '48k']
tmp = tempfile.mkdtemp()
for voice in ['', 'male']:
    base = os.path.join(ROOT, voice)
    # 1) Cắt mọi clip (trừ thư mục male khi đang ở giọng nữ)
    for d in ['countdown', 'cues', 'form', 'reps']:
        folder = os.path.join(base, d)
        for f in os.listdir(folder):
            p = os.path.join(folder, f)
            if not f.endswith('.mp3') or os.path.getsize(p) == 0: continue
            out = os.path.join(tmp, 'o.mp3')
            run(['-i', p, '-af', trim_filter(0.10)] + ENC + [out])
            shutil.move(out, p)
    # 2) Ghép sẵn 11..99 (trừ tròn chục): phần đầu chỉ chừa 0,03 s lặng
    reps = os.path.join(base, 'reps')
    def unit_file(u, teen):
        if u == 5: return 'lam.mp3'
        if u == 1 and not teen: return 'mot.mp3'
        if u == 4 and not teen: return 'tu.mp3'
        return f'{u}.mp3'
    for n in range(11, 100):
        if n % 10 == 0: continue
        first = '10.mp3' if n < 20 else f'{n // 10 * 10}.mp3'
        second = unit_file(n % 10, n < 20)
        out = os.path.join(tmp, 'c.mp3')
        run(['-i', os.path.join(reps, first), '-i', os.path.join(reps, second), '-filter_complex',
             '[0:a]areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03,areverse[a];'
             '[a][1:a]concat=n=2:v=0:a=1'] + ENC + [out])
        shutil.move(out, os.path.join(reps, f'{n}.mp3'))
    print(voice or 'female', 'ok', len(os.listdir(reps)), 'files in reps')
