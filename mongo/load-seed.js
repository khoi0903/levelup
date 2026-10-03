// Nạp dữ liệu mẫu vào database fitness. Chạy lại nhiều lần vẫn an toàn (upsert theo slug).
// docker compose tự chạy file này sau init.js. Chạy tay:
//   docker compose run --rm mongo-init
//
// - seed/exercises.json : bài tập (Codex soạn)
// - cv-configs.json     : cấu hình đếm bằng camera theo slug (Claude Code quản lý)
// - seed/foods.json     : kho món Việt cho F8 (upsert theo searchName, chỉ món curated)
// - seed/achievements.json : danh mục huy hiệu (upsert theo code)

const fs = require("fs");
const dbx = db.getSiblingDB("fitness");

const exercises = JSON.parse(fs.readFileSync("/seed/exercises.json", "utf8"));
const cvConfigs = JSON.parse(fs.readFileSync("/scripts/cv-configs.json", "utf8"));

let upserted = 0;
for (const e of exercises) {
  const doc = { ...e, difficulty: NumberInt(e.difficulty) };
  const cv = cvConfigs[e.slug];
  if (cv) {
    doc.cv = {
      supported: true,
      activeVersion: NumberInt(cv.activeVersion),
      configs: cv.configs.map(c => ({ ...c, version: NumberInt(c.version), createdAt: new Date() })),
    };
  }
  dbx.exercises.updateOne({ slug: e.slug }, { $set: doc }, { upsert: true });
  upserted++;
}

const withCamera = dbx.exercises.countDocuments({ "cv.activeVersion": { $exists: true } });
print("Đã nạp " + upserted + " bài tập (" + withCamera + " bài có cấu hình camera).");

// Kho món Việt (F8). Chỉ ghi đè món curated, không đụng món người dùng hay AI thêm.
const foods = JSON.parse(fs.readFileSync("/seed/foods.json", "utf8"));
let foodCount = 0;
for (const f of foods) {
  const doc = { ...f, source: "curated" };
  dbx.foods.updateOne({ searchName: f.searchName, source: "curated" },
    { $set: doc, $setOnInsert: { createdAt: new Date() } }, { upsert: true });
  foodCount++;
}
print("Đã nạp " + foodCount + " món ăn.");

// Danh mục huy hiệu
const achievements = JSON.parse(fs.readFileSync("/seed/achievements.json", "utf8"));
for (const a of achievements) {
  const doc = { ...a };
  if (a.threshold !== undefined) doc.threshold = NumberInt(a.threshold);
  dbx.achievements.updateOne({ code: a.code }, { $set: doc }, { upsert: true });
}
print("Đã nạp " + achievements.length + " huy hiệu.");
