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
    ("cues/next_exercise.mp3", "Bài tiếp theo:"),
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

EXERCISE_ITEMS = [
    ("exercises/jumping-jack.mp3", "Bật nhảy tại chỗ"),
    ("exercises/bodyweight-squat.mp3", "Squat không tạ"),
    ("exercises/goblet-squat.mp3", "Squat ôm tạ"),
    ("exercises/plank.mp3", "Plank"),
    ("exercises/glute-bridge.mp3", "Nâng hông"),
    ("exercises/dead-bug.mp3", "Duỗi tay chân đối bên"),
    ("exercises/push-up.mp3", "Hít đất"),
    ("exercises/reverse-lunge.mp3", "Lunge bước lùi"),
    ("exercises/dumbbell-shoulder-press.mp3", "Đẩy vai tạ đơn"),
    ("exercises/standing-calf-raise.mp3", "Nhón gót đứng"),
    ("exercises/wall-sit.mp3", "Ngồi tựa tường"),
    ("exercises/bird-dog.mp3", "Vươn tay chân đối bên"),
    ("exercises/side-lying-leg-raise.mp3", "Nằm nghiêng nâng chân"),
    ("exercises/wall-push-up.mp3", "Hít đất vào tường"),
    ("exercises/march-in-place.mp3", "Đi bộ tại chỗ"),
    ("exercises/step-jack.mp3", "Bước ngang kết hợp đưa tay"),
    ("exercises/dumbbell-bent-over-row.mp3", "Kéo tạ đơn gập người"),
    ("exercises/seated-resistance-band-row.mp3", "Ngồi kéo dây kháng lực"),
    ("exercises/dumbbell-biceps-curl.mp3", "Cuốn tay trước với tạ đơn"),
    ("exercises/dumbbell-floor-press.mp3", "Đẩy ngực tạ đơn trên sàn"),
    ("exercises/arm-circles.mp3", "Xoay tay vòng tròn nhỏ"),
    ("exercises/prone-y-t-raise.mp3", "Nâng tay chữ Y và T nằm sấp"),
    ("exercises/wall-slide.mp3", "Trượt tay trên tường"),
    ("exercises/close-grip-wall-push-up.mp3", "Hít đất tường tay hẹp"),
    ("exercises/wall-triceps-extension.mp3", "Duỗi tay sau vào tường"),
    ("exercises/self-resisted-biceps-curl.mp3", "Cuốn tay trước tự kháng lực"),
    ("exercises/low-superman.mp3", "Nâng thân nằm sấp nhẹ"),
    ("exercises/prone-snow-angel.mp3", "Thiên thần tuyết nằm sấp"),
    ("exercises/prone-row.mp3", "Chèo tay nằm sấp không tạ"),
    ("exercises/supine-heel-slide.mp3", "Trượt gót nằm ngửa"),
    ("exercises/slow-mountain-climber.mp3", "Kéo gối chậm chống tay"),
    ("exercises/quadruped-glute-kickback.mp3", "Đá chân sau chống gối"),
    ("exercises/standing-hamstring-curl.mp3", "Gập gối đứng không tạ"),
    ("exercises/side-step-touch.mp3", "Bước ngang chạm chân"),
]

TIPS_ITEMS = [
    ("tips/jumping-jack.mp3", "Tiếp đất nhẹ với gối hơi chùng"),
    ("tips/bodyweight-squat.mp3", "Giữ gót bám sàn, gối theo hướng mũi chân"),
    ("tips/goblet-squat.mp3", "Giữ tạ sát ngực, gối theo hướng mũi chân"),
    ("tips/plank.mp3", "Đặt khuỷu tay dưới vai, giữ hông ngang thân"),
    ("tips/glute-bridge.mp3", "Nâng hông bằng cơ mông, giữ lưng ổn định"),
    ("tips/dead-bug.mp3", "Duỗi tay chân đối bên chậm, giữ lưng dưới ổn định"),
    ("tips/push-up.mp3", "Siết bụng nhẹ, giữ vai, hông, cổ chân thẳng hàng"),
    ("tips/reverse-lunge.mp3", "Bước lùi chậm, giữ gối trước theo hướng mũi chân"),
    ("tips/dumbbell-shoulder-press.mp3", "Siết bụng nhẹ, giữ lưng ổn định khi đẩy tạ"),
    ("tips/standing-calf-raise.mp3", "Nhón gót chậm, chạm tay vào tường để giữ thăng bằng"),
    ("tips/wall-sit.mp3", "Tựa lưng vào tường, giữ gối theo hướng mũi chân"),
    ("tips/bird-dog.mp3", "Vươn tay chân đối bên chậm, giữ lưng ổn định"),
    ("tips/side-lying-leg-raise.mp3", "Giữ hông và vai xếp chồng, mũi chân hướng trước"),
    ("tips/wall-push-up.mp3", "Đặt tay ngang ngực, giữ thân thẳng khi nghiêng vào tường"),
    ("tips/march-in-place.mp3", "Nâng gối vừa tầm, giữ thân thẳng và ổn định"),
    ("tips/step-jack.mp3", "Bước ngang vừa tầm, luôn giữ một chân trên sàn"),
    ("tips/dumbbell-bent-over-row.mp3", "Gập từ hông, giữ lưng tự nhiên và thân ổn định"),
    ("tips/seated-resistance-band-row.mp3", "Giữ dây chắc quanh bàn chân, lưng thẳng tự nhiên"),
    ("tips/dumbbell-biceps-curl.mp3", "Giữ khuỷu tay sát thân và cổ tay thẳng"),
    ("tips/dumbbell-floor-press.mp3", "Giữ cổ tay thẳng khi đẩy tạ lên trên ngực"),
    ("tips/arm-circles.mp3", "Xoay vòng nhỏ, giữ vai xa tai"),
    ("tips/prone-y-t-raise.mp3", "Nâng tay thấp, giữ ngực trên thảm và cổ thẳng"),
    ("tips/wall-slide.mp3", "Trượt tay chậm, giữ bụng nhẹ và vai thả lỏng"),
    ("tips/close-grip-wall-push-up.mp3", "Giữ khuỷu sát thân, đưa ngực gần tường chậm"),
    ("tips/wall-triceps-extension.mp3", "Gập khuỷu chậm, giữ thân thẳng và đầu cách tường"),
    ("tips/self-resisted-biceps-curl.mp3", "Dùng lực cản nhẹ, giữ cổ tay thẳng"),
    ("tips/low-superman.mp3", "Nâng thân thấp, giữ cổ theo đường lưng"),
    ("tips/prone-snow-angel.mp3", "Quét tay chậm, giữ ngực trên thảm"),
    ("tips/prone-row.mp3", "Kéo khuỷu về sườn, giữ vai xa tai"),
    ("tips/supine-heel-slide.mp3", "Trượt gót chậm, giữ lưng dưới ổn định"),
    ("tips/slow-mountain-climber.mp3", "Kéo gối chậm, giữ hông ổn định"),
    ("tips/quadruped-glute-kickback.mp3", "Giữ gối gập, nâng đùi trong tầm thoải mái"),
    ("tips/standing-hamstring-curl.mp3", "Gập gối chậm, chạm tay vào tường giữ thăng bằng"),
    ("tips/side-step-touch.mp3", "Bước ngắn, đặt chân nhẹ và thở đều"),
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

    all_items = REPS_ITEMS + COMMON_ITEMS + EXERCISE_ITEMS + TIPS_ITEMS

    print("--- Sinh audio Nữ ---")
    for rel_path, text in all_items:
        await generate_file(rel_path, text, female_dir, VOICE_FEMALE)

    print("--- Sinh audio Nam ---")
    for rel_path, text in all_items:
        await generate_file(rel_path, text, male_dir, VOICE_MALE)

    print("All audio files generated successfully!")

if __name__ == "__main__":
    asyncio.run(main())
