// =====================================================================
// Fitness app MVP · MongoDB schema
// Chạy: mongosh "<connection string>/fitness" init.js
// Yêu cầu: MongoDB 7+ chạy dạng replica set (Atlas mặc định 3 node)
//          để có transaction và change stream.
// Quy ước: _id là ObjectId; thời điểm là Date (UTC);
//          "ngày" của người dùng lưu chuỗi "YYYY-MM-DD" ở localDate;
//          tuần bắt đầu Thứ Hai, lưu ở weekStart "YYYY-MM-DD".
// =====================================================================

const dbx = db.getSiblingDB("fitness");

// Tạo collection kèm validator. Chạy lại nhiều lần vẫn an toàn.
function coll(name, schema, opts = {}) {
  const exists = dbx.getCollectionNames().includes(name);
  if (!exists) {
    dbx.createCollection(name, { ...(schema ? { validator: { $jsonSchema: schema } } : {}), ...opts });
  } else if (schema) {
    dbx.runCommand({ collMod: name, validator: { $jsonSchema: schema } });
  }
  return dbx.getCollection(name);
}

const DATE_STR = { bsonType: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" };
const BODY_AREA = { enum: ["lower_back", "knee", "shoulder", "neck", "wrist", "ankle", "hip", "other"] };
const VARIANT = { enum: ["normal", "light", "quick5", "advanced"] };

// ---------------------------------------------------------------------
// users: hồ sơ + mọi thứ nhỏ, có giới hạn, luôn đọc cùng người dùng (F1)
// ---------------------------------------------------------------------
coll("users", {
  bsonType: "object",
  required: ["displayName", "timezone", "createdAt"],
  properties: {
    authUid:     { bsonType: "string" },              // uid từ Firebase Auth
    email:       { bsonType: "string" },
    phone:       { bsonType: "string" },
    displayName: { bsonType: "string" },
    timezone:    { bsonType: "string" },              // "Asia/Ho_Chi_Minh"
    locale:      { bsonType: "string" },
    profile: {
      bsonType: "object",
      properties: {
        goal:           { enum: ["lose_fat", "build_muscle", "get_healthier", "maintain"] },
        gender:         { enum: ["male", "female", "other"] },
        birthYear:      { bsonType: "number", minimum: 1900, maximum: 2100 },
        heightCm:       { bsonType: "number", minimum: 80, maximum: 250 },
        startWeightKg:  { bsonType: "number", minimum: 20, maximum: 350 },
        goalWeightKg:   { bsonType: "number", minimum: 20, maximum: 350 },
        experience:     { enum: ["beginner", "intermediate", "regular"] },
        location:       { enum: ["home", "gym", "outdoor"] },
        sessionMinutes: { bsonType: "number", minimum: 5, maximum: 180 },
        coachStyle:     { enum: ["strict", "supportive", "funny"] },
        motivationReasons: { bsonType: "array", items: { bsonType: "string" } },
        motivationText: { bsonType: "string" },       // AI dùng lại khi người dùng nản
        equipment:      { bsonType: "array", items: { bsonType: "string" } },
        onboardingCompletedAt: { bsonType: "date" }
      }
    },
    injuries: {                                       // lọc bài tập
      bsonType: "array",
      items: {
        bsonType: "object", required: ["bodyArea", "active"],
        properties: { bodyArea: BODY_AREA, note: { bsonType: "string" }, active: { bsonType: "bool" },
                      reportedAt: { bsonType: "date" }, resolvedAt: { bsonType: "date" } }
      }
    },
    availability: {
      bsonType: "array",
      items: { bsonType: "object", required: ["weekday", "slot"],
               properties: { weekday: { bsonType: "number", minimum: 1, maximum: 7 },
                             slot: { enum: ["early_morning", "noon", "evening", "late_evening"] } } }
    },
    notificationSettings: {
      bsonType: "object",
      properties: {
        pushEnabled:       { bsonType: "bool" },
        checkinTime:       { bsonType: "string" },    // "07:30"
        preWorkoutMinutes: { bsonType: "number" },
        quietStart:        { bsonType: "string" },    // "22:00"
        quietEnd:          { bsonType: "string" },    // "07:00"
        maxPerDay:         { bsonType: "number", minimum: 0, maximum: 5 },
        waterReminder:     { bsonType: "bool" }       // nhắc uống nước, tự bật, không tính vào maxPerDay
      }
    },
    exerciseDislikes: { bsonType: "array", items: { bsonType: "objectId" } },  // "Không gợi ý bài này nữa"
    devices: { bsonType: "array", items: { bsonType: "object",
               properties: { platform: { enum: ["ios", "android", "web"] }, token: { bsonType: "string" }, lastSeenAt: { bsonType: "date" } } } },
    sharing: { bsonType: "object", properties: {                         // buddy thấy gì (mặc định tắt hết)
               weight: { bsonType: "bool" }, measurements: { bsonType: "bool" }, photos: { bsonType: "bool" }, meals: { bsonType: "bool" } } },
    nutritionTargets: { bsonType: "array", items: { bsonType: "object",   // lịch sử, phần tử cuối là hiện tại
               required: ["effectiveFrom", "kcal"],
               properties: { effectiveFrom: DATE_STR, kcal: { bsonType: "number", minimum: 1200 },
                             proteinG: { bsonType: "number" }, carbsG: { bsonType: "number" }, fatG: { bsonType: "number" },
                             waterMl: { bsonType: "number" }, method: { bsonType: "string" } } } },
    streak: { bsonType: "object", properties: {                          // F4, tổng hợp để đọc nhanh
               currentWeeks: { bsonType: "number" }, bestWeeks: { bsonType: "number" },
               freezesAvailable: { bsonType: "number", minimum: 0, maximum: 2 }, lastClosedWeek: DATE_STR } },
    reengagement: { bsonType: "object", properties: {                    // F3, bậc nhắc quay lại
               stage: { enum: ["active", "missed_1", "missed_2", "lapsed_7", "lapsed_14", "dormant"] },
               lastWorkoutAt: { bsonType: "date" }, consecutiveMissed: { bsonType: "number" },
               stageEnteredAt: { bsonType: "date" }, messagesInStage: { bsonType: "number" } } },
    achievements: { bsonType: "array", items: { bsonType: "object",       // F7, vài chục phần tử là tối đa
               required: ["code", "earnedAt"],
               properties: { code: { bsonType: "string" }, earnedAt: { bsonType: "date" }, context: { bsonType: "object" } } } },
    coachMemory: { bsonType: "array", maxItems: 50, items: { bsonType: "object",   // "đau vai phải từ 26/9"
               required: ["key", "value"],
               properties: { key: { bsonType: "string" }, value: { bsonType: "string" },
                             updatedAt: { bsonType: "date" }, expiresAt: { bsonType: "date" } } } },
    subscription: { bsonType: "object", properties: {
               tier: { enum: ["free", "premium"] }, provider: { bsonType: "string" }, currentPeriodEnd: { bsonType: "date" } } },
    consents: { bsonType: "array", items: { bsonType: "object",           // không ghi đè, chỉ thêm
               required: ["kind", "version", "grantedAt"],
               properties: { kind: { bsonType: "string" }, version: { bsonType: "string" },
                             grantedAt: { bsonType: "date" }, revokedAt: { bsonType: "date" } } } },
    experiments: { bsonType: "object" },              // { "f3_ai_vs_fixed": "ai" }
    createdAt:    { bsonType: "date" },
    lastActiveAt: { bsonType: "date" },
    deletedAt:    { bsonType: "date" }
  }
});
dbx.users.createIndex({ authUid: 1 }, { unique: true, partialFilterExpression: { authUid: { $type: "string" } } });
dbx.users.createIndex({ email: 1 }, { unique: true, partialFilterExpression: { email: { $type: "string" } } });
dbx.users.createIndex({ "devices.token": 1 });
dbx.users.createIndex({ "reengagement.stage": 1, timezone: 1 });   // job nhắc quay lại
dbx.users.createIndex({ deletedAt: 1 }, { partialFilterExpression: { deletedAt: { $type: "date" } } });

// ---------------------------------------------------------------------
// Thư viện bài tập
// ---------------------------------------------------------------------
coll("exercises", {
  bsonType: "object",
  required: ["slug", "nameVi", "primaryMuscle", "difficulty", "tracking"],
  properties: {
    slug: { bsonType: "string" }, nameVi: { bsonType: "string" }, nameEn: { bsonType: "string" },
    instructions: { bsonType: "string" },
    cues: { bsonType: "array", items: { bsonType: "string" } },
    videoUrl: { bsonType: "string" }, thumbnailUrl: { bsonType: "string" },
    primaryMuscle: { bsonType: "string" },
    difficulty: { bsonType: "number", minimum: 1, maximum: 5 },
    tracking: { enum: ["reps", "reps_weight", "duration"] },
    met: { bsonType: "number" },
    equipment: { bsonType: "array", items: { bsonType: "string" } },         // rỗng = không cần dụng cụ
    contraindications: { bsonType: "array", items: BODY_AREA },              // tránh khi đau vùng này
    alternatives: { bsonType: "array", items: { bsonType: "object",           // nút "Đổi bài"
                    properties: { exerciseId: { bsonType: "objectId" }, reason: { bsonType: "string" } } } },
    cv: { bsonType: "object", properties: {                                  // F2b camera
          supported: { bsonType: "bool" },
          activeVersion: { bsonType: "number" },
          configs: { bsonType: "array", items: { bsonType: "object",
                     required: ["version", "cameraPosition", "config"],
                     properties: { version: { bsonType: "number" }, cameraPosition: { enum: ["side", "front"] },
                                   config: { bsonType: "object" },  // khớp, ngưỡng góc, độ tin cậy, luật tư thế
                                   createdAt: { bsonType: "date" } } } } } },
    isActive: { bsonType: "bool" }
  }
});
dbx.exercises.createIndex({ slug: 1 }, { unique: true });
dbx.exercises.createIndex({ isActive: 1, equipment: 1 });
dbx.exercises.createIndex({ contraindications: 1 });

coll("workout_templates", {
  bsonType: "object",
  required: ["slug", "nameVi", "focus", "level", "durationMin", "items"],
  properties: {
    slug: { bsonType: "string" }, nameVi: { bsonType: "string" }, focus: { bsonType: "string" },
    level: { enum: ["beginner", "intermediate", "regular"] }, durationMin: { bsonType: "number" }, variant: VARIANT,
    items: { bsonType: "array", items: { bsonType: "object", required: ["exerciseId"],
             properties: { exerciseId: { bsonType: "objectId" }, sets: { bsonType: "number" }, reps: { bsonType: "number" },
                           durationSec: { bsonType: "number" }, restSec: { bsonType: "number" } } } },
    isActive: { bsonType: "bool" }
  }
});
dbx.workout_templates.createIndex({ slug: 1 }, { unique: true });

// ---------------------------------------------------------------------
// Kế hoạch tuần: nhúng các buổi (tối đa 7) và động tác của từng buổi
// ---------------------------------------------------------------------
const PLANNED_SESSION = {
  bsonType: "object",
  required: ["_id", "scheduledDate", "title", "durationMin", "status"],
  properties: {
    _id: { bsonType: "objectId" },
    scheduledDate: DATE_STR, scheduledTime: { bsonType: "string" },
    templateId: { bsonType: "objectId" },
    title: { bsonType: "string" }, durationMin: { bsonType: "number" }, variant: VARIANT,
    status: { enum: ["planned", "completed", "skipped", "rescheduled", "rest"] },
    rescheduledFromId: { bsonType: "objectId" },
    adjustedReason: { bsonType: "string" },          // "checkin_tired", "pain_shoulder", "skip_busy"
    workoutLogId: { bsonType: "objectId" },
    items: { bsonType: "array", items: { bsonType: "object", required: ["exerciseId"],
             properties: { exerciseId: { bsonType: "objectId" }, targetSets: { bsonType: "number" },
                           targetReps: { bsonType: "number" }, targetWeightKg: { bsonType: "number" },
                           targetDurationSec: { bsonType: "number" }, restSec: { bsonType: "number" } } } }
  }
};
coll("training_plans", {
  bsonType: "object",
  required: ["userId", "weekStart", "status", "targetSessions", "sessions", "createdAt"],
  properties: {
    userId: { bsonType: "objectId" }, weekStart: DATE_STR,
    status: { enum: ["draft", "active", "completed", "replaced"] },
    targetSessions: { bsonType: "number", minimum: 1, maximum: 7 },
    createdBy: { enum: ["ai", "user", "rule"] },
    aiRationale: { bsonType: "string" },
    sourceReviewId: { bsonType: "objectId" },
    sessions: { bsonType: "array", maxItems: 14, items: PLANNED_SESSION },
    createdAt: { bsonType: "date" }
  }
});
dbx.training_plans.createIndex({ userId: 1, weekStart: 1 }, { unique: true, partialFilterExpression: { status: "active" } });
dbx.training_plans.createIndex({ "sessions.scheduledDate": 1, "sessions.status": 1 });  // job nhắc bỏ buổi
dbx.training_plans.createIndex({ userId: 1, "sessions.scheduledDate": 1 });

// ---------------------------------------------------------------------
// Buổi đã tập: nhúng các hiệp, kết quả camera và lỗi tư thế
// ---------------------------------------------------------------------
coll("workout_logs", {
  bsonType: "object",
  required: ["userId", "startedAt", "localDate", "variant", "sets"],
  properties: {
    userId: { bsonType: "objectId" },
    clientId: { bsonType: "string" },                 // app sinh, chống lưu trùng khi gửi lại
    planId: { bsonType: "objectId" }, plannedSessionId: { bsonType: "objectId" },
    startedAt: { bsonType: "date" }, endedAt: { bsonType: "date" },
    localDate: DATE_STR, weekStart: DATE_STR,
    durationSec: { bsonType: "number", minimum: 0 },
    variant: VARIANT,
    rpe: { bsonType: "number", minimum: 1, maximum: 10 },
    painAreas: { bsonType: "array", items: BODY_AREA },
    note: { bsonType: "string" },
    kcalEstimate: { bsonType: "number" },
    countsForStreak: { bsonType: "bool" },           // backend đặt = durationSec >= 300
    newRecords: { bsonType: "array" },               // kỷ lục mới của buổi này, để trả lại khi app gửi trùng
    sets: { bsonType: "array", maxItems: 200, items: { bsonType: "object",
      required: ["exerciseId", "setIndex"],
      properties: {
        exerciseId: { bsonType: "objectId" }, setIndex: { bsonType: "number" },
        reps: { bsonType: "number" },                   // số cuối cùng người dùng xác nhận
        weightKg: { bsonType: "number" }, durationSec: { bsonType: "number" },
        isPr: { bsonType: "bool" }, loggedAt: { bsonType: "date" },
        repSource: { enum: ["manual", "camera", "camera_corrected"] },
        repsDetected: { bsonType: "number" },           // camera đếm được
        cvVersion: { bsonType: "number" },
        avgConfidence: { bsonType: "number", minimum: 0, maximum: 1 },
        formScore: { bsonType: "number", minimum: 0, maximum: 100 },
        formIssues: { bsonType: "array", items: { bsonType: "object",
          properties: { repIndex: { bsonType: "number" }, code: { bsonType: "string" },
                        severity: { bsonType: "number", minimum: 1, maximum: 3 } } } }
      } } },
    createdAt: { bsonType: "date" }
  }
});
dbx.workout_logs.createIndex({ userId: 1, localDate: -1 });
dbx.workout_logs.createIndex({ userId: 1, clientId: 1 }, { unique: true, partialFilterExpression: { clientId: { $type: "string" } } });   // app gửi lại không lưu trùng
dbx.workout_logs.createIndex({ userId: 1, weekStart: 1, countsForStreak: 1 });
dbx.workout_logs.createIndex({ "sets.exerciseId": 1, "sets.repSource": 1 });   // đo độ chính xác camera

coll("personal_records", {
  bsonType: "object",
  required: ["userId", "exerciseId", "metric", "value", "achievedAt"],
  properties: {
    userId: { bsonType: "objectId" }, exerciseId: { bsonType: "objectId" },
    metric: { enum: ["max_weight", "max_reps", "max_duration", "max_volume"] },
    value: { bsonType: "number" }, workoutLogId: { bsonType: "objectId" }, achievedAt: { bsonType: "date" }
  }
});
dbx.personal_records.createIndex({ userId: 1, exerciseId: 1, metric: 1 }, { unique: true });

// ---------------------------------------------------------------------
// daily_stats: một document cho mỗi người mỗi ngày
// gộp check-in (F2), nước uống (F8), lượt dùng gói miễn phí
// ---------------------------------------------------------------------
coll("daily_stats", {
  bsonType: "object",
  required: ["userId", "localDate"],
  properties: {
    userId: { bsonType: "objectId" }, localDate: DATE_STR,
    checkin: { bsonType: "object", properties: {
               energy: { enum: ["tired", "normal", "energized"] },
               sleep: { enum: ["lt6", "h6_7", "h7_8", "gt8"] }, at: { bsonType: "date" } } },
    waterMl: { bsonType: "number", minimum: 0 },
    usage: { bsonType: "object", properties: { photoScans: { bsonType: "number" }, coachMessages: { bsonType: "number" },
                                               voiceLines: { bsonType: "number" } } },  // voiceLines: câu AI giọng coach (Pro)
    notificationsSent: { bsonType: "number", minimum: 0 },  // đếm nhanh cho giới hạn 2 lần/ngày
    waterRemindersSent: { bsonType: "number", minimum: 0 },  // nhắc uống nước đếm riêng, tối đa 2
    activity: { bsonType: "object", properties: {            // Health Connect: cộng dồn từ 0h, chỉ tăng
                steps: { bsonType: "number", minimum: 0 }, activeKcal: { bsonType: "number", minimum: 0 },
                activeKcalInWorkouts: { bsonType: "number", minimum: 0 },  // phần trùng giờ tập trong app
                source: { enum: ["health_connect"] }, updatedAt: { bsonType: "date" } } }
  }
});
dbx.daily_stats.createIndex({ userId: 1, localDate: 1 }, { unique: true });

// ---------------------------------------------------------------------
// Cơ thể
// ---------------------------------------------------------------------
coll("body_measurements", {
  bsonType: "object", required: ["userId", "measuredOn"],
  properties: { userId: { bsonType: "objectId" }, measuredOn: DATE_STR,
                weightKg: { bsonType: "number" }, waistCm: { bsonType: "number" },
                hipCm: { bsonType: "number" }, chestCm: { bsonType: "number" },
                armCm: { bsonType: "number" }, bodyFatPct: { bsonType: "number" },
                source: { bsonType: "string" }, createdAt: { bsonType: "date" } }
});
dbx.body_measurements.createIndex({ userId: 1, measuredOn: 1 }, { unique: true });

coll("progress_photos", {
  bsonType: "object", required: ["userId", "takenOn", "pose", "storagePath"],
  properties: { userId: { bsonType: "objectId" }, takenOn: DATE_STR, pose: { enum: ["front", "side", "back"] },
                storagePath: { bsonType: "string" }, createdAt: { bsonType: "date" } }
});
dbx.progress_photos.createIndex({ userId: 1, takenOn: -1 });

// ---------------------------------------------------------------------
// Động lực (F3–F6)
// ---------------------------------------------------------------------
coll("weekly_streaks", {
  bsonType: "object", required: ["userId", "weekStart", "targetSessions", "completedSessions", "status"],
  properties: { userId: { bsonType: "objectId" }, weekStart: DATE_STR,
                targetSessions: { bsonType: "number" }, completedSessions: { bsonType: "number" },
                status: { enum: ["in_progress", "achieved", "frozen", "missed"] },
                freezeEvent: { enum: ["earned", "used"] }, closedAt: { bsonType: "date" } }
});
dbx.weekly_streaks.createIndex({ userId: 1, weekStart: 1 }, { unique: true });
dbx.weekly_streaks.createIndex({ weekStart: 1, status: 1 });        // job chốt tuần

coll("skip_reports", {
  bsonType: "object", required: ["userId", "reason", "action", "createdAt"],
  properties: { userId: { bsonType: "objectId" }, planId: { bsonType: "objectId" }, plannedSessionId: { bsonType: "objectId" },
                reason: { enum: ["busy", "tired", "pain", "bored", "forgot", "other"] },
                action: { enum: ["rescheduled", "shortened", "reduced_intensity", "swapped_exercises", "changed_reminder", "rest_day", "none"] },
                note: { bsonType: "string" }, bodyArea: BODY_AREA,                 // bắt buộc khi reason = pain (API kiểm tra)
                coachMessageId: { bsonType: "objectId" }, createdAt: { bsonType: "date" } }
});
dbx.skip_reports.createIndex({ reason: 1, createdAt: -1 });
dbx.skip_reports.createIndex({ userId: 1, createdAt: -1 });

coll("buddy_invites", {
  bsonType: "object", required: ["inviterId", "code", "expiresAt"],
  properties: { inviterId: { bsonType: "objectId" }, code: { bsonType: "string" }, expiresAt: { bsonType: "date" },
                acceptedBy: { bsonType: "objectId" }, acceptedAt: { bsonType: "date" }, createdAt: { bsonType: "date" } }
});
dbx.buddy_invites.createIndex({ code: 1 }, { unique: true });
dbx.buddy_invites.createIndex({ inviterId: 1, expiresAt: -1 });                // mã còn hạn của người mời
// Tự xóa mã 30 ngày sau khi hết hạn: trong 30 ngày đó nhập mã cũ vẫn báo được "mã đã hết hạn" (410)
const INVITE_PURGE_SEC = 60 * 60 * 24 * 30;
const inviteTtl = dbx.buddy_invites.getIndexes().find(i => i.name === "expiresAt_1");
if (!inviteTtl) {
  dbx.buddy_invites.createIndex({ expiresAt: 1 }, { expireAfterSeconds: INVITE_PURGE_SEC });
} else if (inviteTtl.expireAfterSeconds !== INVITE_PURGE_SEC) {
  dbx.runCommand({ collMod: "buddy_invites", index: { name: "expiresAt_1", expireAfterSeconds: INVITE_PURGE_SEC } });
}

coll("buddy_pairs", {
  bsonType: "object", required: ["members", "pairKey", "status"],
  properties: { members: { bsonType: "array", minItems: 2, maxItems: 2, items: { bsonType: "objectId" } },
                pairKey: { bsonType: "string" },    // "<idNhỏ>_<idLớn>" để mỗi cặp chỉ có một document
                status: { enum: ["active", "ended"] }, sharedStreakWeeks: { bsonType: "number" },
                lastSharedWeek: DATE_STR,          // tuần gần nhất đã tính streak chung (chống tính hai lần)
                createdAt: { bsonType: "date" }, endedAt: { bsonType: "date" } }
});
dbx.buddy_pairs.createIndex({ pairKey: 1 }, { unique: true, partialFilterExpression: { status: "active" } });
dbx.buddy_pairs.createIndex({ members: 1, status: 1 });
// Index nhiều khóa (multikey) unique: một người chỉ ở trong tối đa một cặp đang active
dbx.buddy_pairs.createIndex({ members: 1 }, { unique: true, name: "members_active_unique",
  partialFilterExpression: { status: "active" } });

coll("buddy_actions", {
  bsonType: "object", required: ["pairId", "fromUser", "toUser", "action", "localDate"],
  properties: { pairId: { bsonType: "objectId" }, fromUser: { bsonType: "objectId" }, toUser: { bsonType: "objectId" },
                action: { enum: ["cheer", "nudge"] }, localDate: DATE_STR, message: { bsonType: "string", maxLength: 140 },
                createdAt: { bsonType: "date" } }
});
// "Nhắc bạn" và "Cổ vũ": mỗi loại 1 lần/ngày (localDate theo giờ người gửi).
// Thay index cũ chỉ chặn nudge.
if (dbx.buddy_actions.getIndexes().some(i => i.name === "fromUser_1_toUser_1_localDate_1")) {
  dbx.buddy_actions.dropIndex("fromUser_1_toUser_1_localDate_1");
}
dbx.buddy_actions.createIndex({ fromUser: 1, toUser: 1, localDate: 1, action: 1 }, { unique: true });
dbx.buddy_actions.createIndex({ toUser: 1, createdAt: -1 });

coll("achievements", {
  bsonType: "object", required: ["code", "nameVi", "descriptionVi", "category"],
  properties: { code: { bsonType: "string" }, nameVi: { bsonType: "string" }, descriptionVi: { bsonType: "string" },
                category: { bsonType: "string" }, threshold: { bsonType: "number" } }
});
dbx.achievements.createIndex({ code: 1 }, { unique: true });

coll("weekly_reviews", {
  bsonType: "object", required: ["userId", "weekStart", "sessionsDone", "sessionsTarget", "recommendation", "decision"],
  properties: { userId: { bsonType: "objectId" }, weekStart: DATE_STR,
                sessionsDone: { bsonType: "number" }, sessionsTarget: { bsonType: "number" },
                totalMinutes: { bsonType: "number" }, avgRpe: { bsonType: "number" },
                wins: { bsonType: "array", items: { bsonType: "object" } },   // [{type:"pr", label:"Squat +2kg"}]
                improvement: { bsonType: "string" },
                win: { bsonType: "string" },                   // 1 chiến thắng (AI hoặc câu mẫu)
                nextWeekSummary: { bsonType: "string" },
                source: { enum: ["ai", "rules"] },
                weightChangeKg: { bsonType: "number" },
                nutrition: { bsonType: "object", properties: { daysLogged: { bsonType: "number" },
                             avgKcal: { bsonType: ["number", "null"] } } },
                recommendation: { enum: ["increase", "keep", "decrease"] },
                proposedPlanId: { bsonType: "objectId" },
                decision: { enum: ["pending", "accepted", "adjusted", "dismissed"] },
                generatedAt: { bsonType: "date" }, viewedAt: { bsonType: "date" }, decidedAt: { bsonType: "date" } }
});
dbx.weekly_reviews.createIndex({ userId: 1, weekStart: 1 }, { unique: true });

// ---------------------------------------------------------------------
// Dinh dưỡng (F8)
// ---------------------------------------------------------------------
coll("foods", {
  bsonType: "object", required: ["nameVi", "searchName", "kcal"],
  properties: { nameVi: { bsonType: "string" },          // "Cơm tấm sườn bì chả"
                searchName: { bsonType: "string" },      // "com tam suon bi cha" (bỏ dấu, chữ thường)
                aliases: { bsonType: "array", items: { bsonType: "string" } },
                category: { bsonType: "string" }, servingDesc: { bsonType: "string" }, servingGrams: { bsonType: "number" },
                kcal: { bsonType: "number" }, proteinG: { bsonType: "number" },
                carbsG: { bsonType: "number" }, fatG: { bsonType: "number" },
                barcode: { bsonType: "string" }, source: { enum: ["curated", "ai", "user"] },
                verified: { bsonType: "bool" }, createdAt: { bsonType: "date" } }
});
dbx.foods.createIndex({ searchName: "text", aliases: "text" }, { default_language: "none" });
dbx.foods.createIndex({ barcode: 1 }, { unique: true, partialFilterExpression: { barcode: { $type: "string" } } });
dbx.foods.createIndex({ searchName: 1 }, { unique: true, partialFilterExpression: { source: "curated" } });  // seed upsert

coll("meal_logs", {
  bsonType: "object", required: ["userId", "localDate", "meal", "method", "kcal", "items"],
  properties: { userId: { bsonType: "objectId" }, localDate: DATE_STR, eatenAt: { bsonType: "date" },
                meal: { enum: ["breakfast", "lunch", "dinner", "snack"] },
                method: { enum: ["photo", "barcode", "voice", "search", "manual"] },
                photoPath: { bsonType: "string" }, recognitionId: { bsonType: "objectId" },
                aiConfidence: { bsonType: "number", minimum: 0, maximum: 1 },
                kcalMin: { bsonType: "number" }, kcalMax: { bsonType: "number" }, kcal: { bsonType: "number" },
                proteinG: { bsonType: "number" }, carbsG: { bsonType: "number" }, fatG: { bsonType: "number" },
                items: { bsonType: "array", maxItems: 30, items: { bsonType: "object", required: ["name", "kcal"],
                  properties: { foodId: { bsonType: "objectId" }, name: { bsonType: "string" },
                                quantity: { bsonType: "number" }, unit: { bsonType: "string" }, grams: { bsonType: "number" },
                                kcal: { bsonType: "number" }, proteinG: { bsonType: "number" },
                                carbsG: { bsonType: "number" }, fatG: { bsonType: "number" },
                                aiSuggested: { bsonType: "bool" }, userEdited: { bsonType: "bool" },
                                aiEstimated: { bsonType: "bool" } } } },
                createdAt: { bsonType: "date" }, updatedAt: { bsonType: "date" } }
});
dbx.meal_logs.createIndex({ userId: 1, localDate: 1 });

coll("food_recognitions", {
  bsonType: "object", required: ["userId", "imageSha256", "model", "rawResult", "createdAt"],
  properties: { userId: { bsonType: "objectId" }, imageSha256: { bsonType: "string" }, model: { bsonType: "string" },
                rawResult: { bsonType: "object" }, latencyMs: { bsonType: "number" },
                costUsd: { bsonType: "number" }, createdAt: { bsonType: "date" } }
});
dbx.food_recognitions.createIndex({ imageSha256: 1 });                      // cache: cùng ảnh không gọi AI lại
dbx.food_recognitions.createIndex({ userId: 1, imageSha256: 1 });          // cache theo từng người dùng
dbx.food_recognitions.createIndex({ createdAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 180 });

// Món chưa có trong kho foods mà AI nhận ra trong ảnh, chờ Admin duyệt.
// key = tên bỏ dấu chữ thường; aiSamples (số AI /100 g) và savedSamples (số gam người dùng lưu) chỉ giữ
// 20/50 lần gần nhất, không chứa userId. Món đã duyệt/bỏ thì không ghi thêm.
coll("food_candidates", {
  bsonType: "object", required: ["key", "nameVi", "status"],
  properties: { key: { bsonType: "string" }, nameVi: { bsonType: "string" },
                status: { enum: ["pending", "approved", "rejected"] },
                userCount: { bsonType: "number" },
                sightings: { bsonType: "number" }, saves: { bsonType: "number" },
                aiSamples: { bsonType: "array" }, savedSamples: { bsonType: "array" },
                foodId: { bsonType: "objectId" }, firstSeenAt: { bsonType: "date" }, lastSeenAt: { bsonType: "date" } }
});
dbx.food_candidates.createIndex({ key: 1 }, { unique: true });
dbx.food_candidates.createIndex({ status: 1, userCount: -1, lastSeenAt: -1 });
// Mỗi người dùng đếm một lần cho mỗi món (userCount); xoá tài khoản thì xoá theo userId
coll("food_candidate_users", {
  bsonType: "object", required: ["key", "userId"],
  properties: { key: { bsonType: "string" }, userId: { bsonType: "objectId" }, at: { bsonType: "date" } }
});
dbx.food_candidate_users.createIndex({ userId: 1, key: 1 }, { unique: true });

// ---------------------------------------------------------------------
// AI coach và thông báo
// ---------------------------------------------------------------------
coll("coach_messages", {
  bsonType: "object", required: ["userId", "role", "content", "createdAt"],
  properties: { userId: { bsonType: "objectId" }, role: { enum: ["user", "coach", "event"] },
                content: { bsonType: "string" },
                card: { bsonType: "object", required: ["type", "status"],          // thẻ hành động, AI chỉ đề xuất
                        properties: { type: { enum: ["adjust_session", "add_injury", "skip_reasons"] },
                                      // skip_reasons (F3, missed_2): các nút lý do, app gọi POST /skip-reports
                                      options: { bsonType: "array", items: { bsonType: "object", required: ["reason", "label"],
                                                 properties: { reason: { bsonType: "string" }, label: { bsonType: "string" } } } },
                                      status: { enum: ["proposed", "applied", "dismissed"] },
                                      planId: { bsonType: "objectId" }, sessionId: { bsonType: "objectId" },
                                      change: { enum: ["light", "quick5", "swap_exercise", "rest"] },
                                      fromExerciseId: { bsonType: "objectId" }, toExerciseId: { bsonType: "objectId" },
                                      reason: { bsonType: "string" }, adjustedReason: { bsonType: "string" },
                                      injury: { bsonType: "object", required: ["bodyArea"],
                                                properties: { bodyArea: BODY_AREA, note: { bsonType: "string" } } },
                                      appliedAt: { bsonType: "date" } } },
                trigger: { bsonType: "string" },                                 // "missed_2", "weekly_review", "user"
                relatedSessionId: { bsonType: "objectId" }, model: { bsonType: "string" },
                tokensIn: { bsonType: "number" }, tokensOut: { bsonType: "number" }, createdAt: { bsonType: "date" } }
});
dbx.coach_messages.createIndex({ userId: 1, createdAt: -1 });

coll("notifications", {
  bsonType: "object", required: ["userId", "type", "channel", "localDate", "scheduledFor"],
  properties: { userId: { bsonType: "objectId" },
                // Không dùng enum: module nào cũng gửi qua NotificationGateway, type mới không được bị từ chối.
                // Đang dùng: checkin, pre_workout, missed_1, missed_2, missed_session, lapsed, comeback, streak_risk,
                // weekly_review, buddy_paired, buddy_cheer, buddy_nudge, milestone, meal_reminder
                type: { bsonType: "string", pattern: "^[a-z0-9_]{1,40}$" },
                title: { bsonType: "string" }, body: { bsonType: "string" },
                data: { bsonType: "object" },                                    // route, id để app mở đúng màn
                channel: { enum: ["push", "in_app"] }, localDate: DATE_STR,
                scheduledFor: { bsonType: "date" }, sentAt: { bsonType: "date" }, openedAt: { bsonType: "date" },
                action: { bsonType: "string" }, relatedSessionId: { bsonType: "objectId" },
                coachMessageId: { bsonType: "objectId" }, abVariant: { bsonType: "string" },
                dedupeKey: { bsonType: "string" }, createdAt: { bsonType: "date" } }
});
// Loại chỉ gửi 1 lần/ngày (checkin, missed_1, weekly_review...) có dedupeKey = "<userId>|<localDate>|<type>"
// để job chạy lại không gửi trùng. Loại gửi nhiều lần (buddy_cheer) để trống dedupeKey.
dbx.notifications.createIndex({ dedupeKey: 1 }, { unique: true, partialFilterExpression: { dedupeKey: { $type: "string" } } });
dbx.notifications.createIndex({ userId: 1, localDate: 1 });
dbx.notifications.createIndex({ sentAt: 1, scheduledFor: 1 });   // tìm thông báo chưa gửi: { sentAt: null }
dbx.notifications.createIndex({ createdAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 365 });

// ---------------------------------------------------------------------
// Đo lường: time series collection, tự xóa sau 1 năm
// ---------------------------------------------------------------------
if (!dbx.getCollectionNames().includes("events")) {
  dbx.createCollection("events", {
    timeseries: { timeField: "occurredAt", metaField: "meta", granularity: "seconds" },
    expireAfterSeconds: 60 * 60 * 24 * 365
  });
}
// document mẫu: { occurredAt: ISODate(), meta: { name: "workout_completed", userId: ObjectId(...) }, props: {...}, appVersion: "0.3.0" }
dbx.events.createIndex({ "meta.name": 1, occurredAt: 1 });

print("Đã tạo " + dbx.getCollectionNames().filter(n => !n.startsWith("system.")).length + " collection.");
