import asyncio
import os
import sys
import edge_tts

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

VOICE_FEMALE = "vi-VN-HoaiMyNeural"
VOICE_MALE = "vi-VN-NamMinhNeural"
RATE = "+10%"

REPS_ITEMS = [
    # 1..10
    ("reps/1.mp3", "Một"),
    ("reps/2.mp3", "Hai"),
    ("reps/3.mp3", "Ba"),
    ("reps/4.mp3", "Bốn"),
    ("reps/5.mp3", "Năm"),
    ("reps/6.mp3", "Sáu"),
    ("reps/7.mp3", "Bảy"),
    ("reps/8.mp3", "Tám"),
    ("reps/9.mp3", "Chín"),
    ("reps/10.mp3", "Mười"),

    # Tròn chục & Trăm
    ("reps/20.mp3", "Hai mươi"),
    ("reps/30.mp3", "Ba mươi"),
    ("reps/40.mp3", "Bốn mươi"),
    ("reps/50.mp3", "Năm mươi"),
    ("reps/60.mp3", "Sáu mươi"),
    ("reps/70.mp3", "Bảy mươi"),
    ("reps/80.mp3", "Tám mươi"),
    ("reps/90.mp3", "Chín mươi"),
    ("reps/100.mp3", "Một trăm"),

    # Âm ghép
    ("reps/mot.mp3", "Mốt"),
    ("reps/tu.mp3", "Tư"),
    ("reps/lam.mp3", "Lăm"),
    ("reps/muoi.mp3", "Mươi"),
]

COMMON_ITEMS = [
    # Countdown
    ("countdown/3.mp3", "Ba"),
    ("countdown/2.mp3", "Hai"),
    ("countdown/1.mp3", "Một"),
    ("countdown/ready.mp3", "Chuẩn bị"),
    ("countdown/go.mp3", "Bắt đầu nào!"),

    # Cues
    ("cues/almost_done_2.mp3", "Còn hai cái nữa thôi!"),
    ("cues/almost_done_3.mp3", "Cố lên, còn ba cái!"),
    ("cues/last_rep.mp3", "Lần cuối, hết mình nào!"),
    ("cues/set_done.mp3", "Hoàn thành hiệp rồi, xuất sắc!"),
    ("cues/rest_start.mp3", "Nghỉ ngơi, hít thở đều nhé."),
    ("cues/rest_ending.mp3", "Sắp vào hiệp mới rồi, chuẩn bị nào."),
    ("cues/lost_person.mp3", "Lùi lại chút để camera thấy cả người nhé."),
    ("cues/workout_done.mp3", "Tuyệt vời! Hoàn thành buổi tập xuất sắc!"),
    ("cues/personal_record.mp3", "Chúc mừng bạn, kỷ lục mới rồi!"),
    ("cues/hold_remaining_10.mp3", "Còn mười giây, giữ vững nhé!"),
    ("cues/hold_remaining_5.mp3", "Cố lên, còn năm giây!"),

    # Form cues
    ("form/squat_shallow.mp3", "Hạ mông sâu hơn một chút."),
    ("form/squat_knees.mp3", "Mở gối theo hướng mũi chân."),
    ("form/straight_back.mp3", "Khóa cơ bụng, giữ thẳng lưng."),
    ("form/hands_overhead.mp3", "Đưa hai tay lên trên đầu."),
    ("form/form_generic.mp3", "Chú ý giữ chắc người và hít thở đều nhé."),
]

sem = asyncio.Semaphore(2)

async def generate_file(rel_path, text, base_dir, voice):
    full_path = os.path.join(base_dir, rel_path)
    if os.path.exists(full_path) and os.path.getsize(full_path) > 500:
        print(f"Skipping existing: {rel_path} ({os.path.basename(base_dir)})")
        return

    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    async with sem:
        for attempt in range(3):
            try:
                communicate = edge_tts.Communicate(text, voice, rate=RATE)
                await communicate.save(full_path)
                print(f"Generated [{voice}]: {rel_path} -> {text}")
                await asyncio.sleep(0.3)
                return
            except Exception as e:
                if attempt == 2:
                    print(f"Failed {rel_path}: {e}")
                await asyncio.sleep(1.0)

async def main():
    root_audio = os.path.join(os.path.dirname(__file__), "audio")
    female_dir = root_audio
    male_dir = os.path.join(root_audio, "male")

    all_items = REPS_ITEMS + COMMON_ITEMS

    print("--- Sinh audio Nữ ---")
    for rel_path, text in all_items:
        await generate_file(rel_path, text, female_dir, VOICE_FEMALE)

    print("--- Sinh audio Nam ---")
    for rel_path, text in all_items:
        await generate_file(rel_path, text, male_dir, VOICE_MALE)

    print("All audio files generated successfully!")

if __name__ == "__main__":
    asyncio.run(main())
