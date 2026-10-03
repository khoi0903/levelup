// Nạp dữ liệu mẫu vào database fitness. Chạy lại nhiều lần vẫn an toàn (upsert theo slug).
// docker compose tự chạy file này sau init.js. Chạy tay:
//   docker compose run --rm mongo-init
//
// - seed/exercises.json : bài tập (Codex soạn)
// - cv-configs.json     : cấu hình đếm bằng camera theo slug (Claude Code quản lý)

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
