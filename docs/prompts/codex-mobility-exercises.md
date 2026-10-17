# Prompt cho Codex – Bài giãn cơ / vận động nhẹ

Dùng cho "Giãn cơ 10 phút" khi người dùng đang đau (hỏi thăm vùng đau) và ngày mệt. Backend (nhánh
feat/be-activity) đã loại nhóm `primaryMuscle: "mobility"` khỏi mọi chỗ tự xếp bài vào kế hoạch tuần
(Week1PlanBuilder, đổi bài khi bỏ buổi/đau, coach), nên bài giãn cơ chỉ xuất hiện khi người dùng tự chọn hoặc ở
"Giãn cơ 10 phút". **Chỉ nạp seed lên Atlas sau khi backend đó đã deploy.**

```
Bạn đang ở nhánh feat/codex-mobility (worktree D:\levelup-worktrees\codex-mobility), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/codex-mobility-exercises.md.
Chỉ sửa mongo/seed/exercises.json (và docs/content nếu cần ghi chú). Không sửa backend/, app/.

1. Thêm 10 bài vào mongo/seed/exercises.json, đúng định dạng các bài hiện có (xem jumping-jack):
   - primaryMuscle: "mobility"; tracking: "duration"; difficulty: 1; met: 2.3; equipment: [] (thảm "mat" được);
     isActive: true; cv: {"supported": false}.
   - slug kebab-case tiếng Anh, nameVi + nameEn, instructions tiếng Việt 2–3 câu (tư thế, giữ bao lâu, thở),
     cues 2–3 câu ngắn.
   - Phủ đủ vùng: cổ (2), vai/ngực (2), lưng trên + lưng dưới (2), hông/mông (2), đùi sau/bắp chân (2).
     Ví dụ: neck-side-stretch, neck-rotation, cross-body-shoulder-stretch, doorway-chest-stretch (không cần cửa:
     dùng tường), cat-cow, child-pose, figure-four-stretch, hip-flexor-lunge-stretch, standing-hamstring-stretch,
     calf-wall-stretch.
   - contraindications: chỉ ghi vùng mà động tác ép trực tiếp lên vùng đang đau (vd neck-rotation → ["neck"],
     hip-flexor-lunge-stretch → ["knee"] vì quỳ gối). Giá trị phải thuộc lower_back|knee|shoulder|neck|wrist|ankle|hip|other.
     Bài nhẹ nhàng cho lưng dưới (cat-cow, child-pose) không ghi lower_back.
2. Kiểm tra JSON hợp lệ và slug không trùng: node -e "const a=require('./mongo/seed/exercises.json');
   const s=new Set(a.map(e=>e.slug)); if(s.size!==a.length) throw 'trùng slug'; console.log(a.length)" → 44.
3. Commit "content: 10 bài giãn cơ (mobility)". Báo Claude Code review.
```

Sau khi merge: Manual Deploy backend (feat/be-activity) trước, rồi người dùng chạy `mongo/setup-atlas.ps1` để nạp bài.
