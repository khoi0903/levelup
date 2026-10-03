-- =====================================================================
-- Fitness app MVP · Database schema
-- PostgreSQL 15+ (chạy được trên Supabase)
-- Quy ước: id uuid, thời điểm dùng timestamptz (UTC),
--          "ngày" theo múi giờ người dùng lưu ở cột local_date.
-- =====================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists citext;     -- email không phân biệt hoa thường
create extension if not exists pg_trgm;    -- tìm món ăn gần đúng
create extension if not exists unaccent;   -- tìm "com tam" ra "cơm tấm"

-- ---------------------------------------------------------------------
-- ENUM
-- ---------------------------------------------------------------------
create type goal_type         as enum ('lose_fat','build_muscle','get_healthier','maintain');
create type gender_type       as enum ('male','female','other');
create type experience_level  as enum ('beginner','intermediate','regular');
create type training_location as enum ('home','gym','outdoor');
create type coach_style       as enum ('strict','supportive','funny');
create type time_window       as enum ('early_morning','noon','evening','late_evening');
create type body_area         as enum ('lower_back','knee','shoulder','neck','wrist','ankle','hip','other');
create type tracking_type     as enum ('reps','reps_weight','duration');
create type session_variant   as enum ('normal','light','quick5','advanced');
create type plan_status       as enum ('draft','active','completed','replaced');
create type planned_status    as enum ('planned','completed','skipped','rescheduled','rest');
create type energy_level      as enum ('tired','normal','energized');
create type sleep_bucket      as enum ('lt6','h6_7','h7_8','gt8');
create type week_status       as enum ('in_progress','achieved','frozen','missed');
create type skip_reason       as enum ('busy','tired','pain','bored','forgot','other');
create type skip_action       as enum ('rescheduled','shortened','reduced_intensity','swapped_exercises','changed_reminder','rest_day','none');
create type reengage_stage    as enum ('active','missed_1','missed_2','lapsed_7','lapsed_14','dormant');
create type buddy_status      as enum ('active','ended');
create type buddy_action      as enum ('cheer','nudge');
create type review_reco       as enum ('increase','keep','decrease');
create type review_decision   as enum ('pending','accepted','adjusted','dismissed');
create type meal_type         as enum ('breakfast','lunch','dinner','snack');
create type input_method      as enum ('photo','barcode','voice','search','manual');
create type food_source       as enum ('curated','ai','user');
create type msg_role          as enum ('user','coach','event');
create type notif_type        as enum ('checkin','pre_workout','missed_1','missed_2','lapsed','weekly_review',
                                       'buddy_cheer','buddy_nudge','milestone','meal_reminder');
create type notif_channel     as enum ('push','in_app');
create type plan_tier         as enum ('free','premium');
create type rep_source        as enum ('manual','camera','camera_corrected');
create type camera_position   as enum ('side','front');

-- =====================================================================
-- 1. NGƯỜI DÙNG & HỒ SƠ  (F1 Onboarding)
-- =====================================================================
create table users (
  id              uuid primary key default gen_random_uuid(),  -- Supabase: references auth.users(id)
  email           citext unique,
  phone           text unique,
  display_name    text not null,
  avatar_url      text,
  timezone        text not null default 'Asia/Ho_Chi_Minh',
  locale          text not null default 'vi',
  created_at      timestamptz not null default now(),
  last_active_at  timestamptz,
  deleted_at      timestamptz                                  -- xóa mềm, job xóa hẳn sau 30 ngày
);

create table user_profiles (
  user_id                  uuid primary key references users(id) on delete cascade,
  goal                     goal_type not null,
  gender                   gender_type,
  birth_year               smallint check (birth_year between 1900 and 2100),
  height_cm                numeric(5,1) check (height_cm between 80 and 250),
  start_weight_kg          numeric(5,1) check (start_weight_kg between 20 and 350),
  goal_weight_kg           numeric(5,1) check (goal_weight_kg between 20 and 350),
  experience               experience_level not null default 'beginner',
  location                 training_location not null default 'home',
  session_minutes          smallint not null default 15 check (session_minutes between 5 and 180),
  coach_style              coach_style not null default 'supportive',
  motivation_text          text,              -- lý do người dùng tự viết, AI dùng lại khi họ nản
  onboarding_completed_at  timestamptz,
  updated_at               timestamptz not null default now()
);

-- Các lựa chọn nhiều giá trị ở onboarding
create table user_motivation_reasons (
  user_id      uuid not null references users(id) on delete cascade,
  reason_code  text not null,                 -- 'confidence','fit_old_clothes','play_with_kids',...
  primary key (user_id, reason_code)
);

create table user_equipment (
  user_id         uuid not null references users(id) on delete cascade,
  equipment_code  text not null,              -- 'dumbbell','mat','resistance_band','pullup_bar'
  primary key (user_id, equipment_code)
);

create table user_injuries (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  body_area    body_area not null,
  note         text,
  active       boolean not null default true,
  reported_at  timestamptz not null default now(),
  resolved_at  timestamptz
);
create index user_injuries_active_idx on user_injuries(user_id) where active;

create table user_availability (
  user_id  uuid not null references users(id) on delete cascade,
  weekday  smallint not null check (weekday between 1 and 7),   -- 1 = Thứ Hai
  slot     time_window not null,
  primary key (user_id, weekday, slot)
);

create table notification_settings (
  user_id              uuid primary key references users(id) on delete cascade,
  push_enabled         boolean not null default false,
  checkin_time         time not null default '07:30',
  pre_workout_minutes  smallint not null default 30,
  quiet_start          time not null default '22:00',
  quiet_end            time not null default '07:00',
  max_per_day          smallint not null default 2 check (max_per_day between 0 and 5),
  updated_at           timestamptz not null default now()
);

create table device_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  platform      text not null check (platform in ('ios','android')),
  token         text not null unique,
  last_seen_at  timestamptz not null default now()
);

-- Buddy chỉ thấy những gì người dùng bật (mặc định tắt hết)
create table sharing_settings (
  user_id             uuid primary key references users(id) on delete cascade,
  share_weight        boolean not null default false,
  share_measurements  boolean not null default false,
  share_photos        boolean not null default false,
  share_meals         boolean not null default false
);

create table subscriptions (
  user_id             uuid primary key references users(id) on delete cascade,
  tier                plan_tier not null default 'free',
  provider            text,                 -- 'app_store','google_play'
  provider_ref        text,
  current_period_end  timestamptz,
  updated_at          timestamptz not null default now()
);

-- Đồng ý xử lý dữ liệu sức khỏe, ảnh cơ thể, thông báo (lưu lịch sử, không ghi đè)
create table user_consents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  kind        text not null,                -- 'health_data','body_photos','ai_processing','camera','cv_training_data','marketing'
  version     text not null,                -- phiên bản điều khoản
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz
);
create index user_consents_user_idx on user_consents(user_id, kind);

-- =====================================================================
-- 2. THƯ VIỆN BÀI TẬP
-- =====================================================================
create table exercises (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,       -- 'goblet-squat'
  name_vi         text not null,              -- 'Squat ôm tạ'
  name_en         text,
  instructions    text,
  cues            text[] not null default '{}',   -- 'Giữ lưng thẳng', ...
  video_url       text,
  thumbnail_url   text,
  primary_muscle  text not null,
  difficulty      smallint not null check (difficulty between 1 and 5),
  tracking        tracking_type not null,
  met             numeric(4,1),               -- dùng ước tính kcal
  cv_supported    boolean not null default false,  -- có nút "Đếm bằng camera"
  is_active       boolean not null default true
);

-- Không có dòng nào = bài không cần dụng cụ
create table exercise_equipment (
  exercise_id     uuid not null references exercises(id) on delete cascade,
  equipment_code  text not null,
  primary key (exercise_id, equipment_code)
);

-- Bài cần tránh khi người dùng đau vùng này
create table exercise_contraindications (
  exercise_id  uuid not null references exercises(id) on delete cascade,
  body_area    body_area not null,
  primary key (exercise_id, body_area)
);

-- Nút "Đổi bài"
create table exercise_alternatives (
  exercise_id     uuid not null references exercises(id) on delete cascade,
  alternative_id  uuid not null references exercises(id) on delete cascade,
  reason          text,                       -- 'no_equipment','easier','shoulder_friendly'
  primary key (exercise_id, alternative_id),
  check (exercise_id <> alternative_id)
);

-- Cấu hình đếm bằng camera cho từng bài, có phiên bản.
-- App tải cấu hình đang bật về máy; nhận diện tư thế chạy trên điện thoại.
create table exercise_cv_configs (
  id               uuid primary key default gen_random_uuid(),
  exercise_id      uuid not null references exercises(id) on delete cascade,
  version          integer not null,
  camera_position  camera_position not null,
  config           jsonb not null,   -- {"joints":["hip","knee","ankle"],"down_below":95,"up_above":160,"min_confidence":0.6,"form_rules":[...]}
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  unique (exercise_id, version)
);
create unique index exercise_cv_configs_one_active_idx
  on exercise_cv_configs(exercise_id) where is_active;

create table workout_templates (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,
  name_vi       text not null,
  focus         text not null,                -- 'full_body','lower_core','cardio'
  level         experience_level not null,
  duration_min  smallint not null,
  variant       session_variant not null default 'normal',
  is_active     boolean not null default true
);

create table workout_template_items (
  template_id   uuid not null references workout_templates(id) on delete cascade,
  position      smallint not null,
  exercise_id   uuid not null references exercises(id),
  sets          smallint,
  reps          smallint,
  duration_sec  smallint,
  rest_sec      smallint not null default 60,
  primary key (template_id, position)
);

-- =====================================================================
-- 3. KẾ HOẠCH & BUỔI TẬP  (F1 kế hoạch tuần 1, F2, F6)
-- =====================================================================
create table training_plans (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id) on delete cascade,
  week_start        date not null,            -- luôn là Thứ Hai
  status            plan_status not null default 'draft',
  target_sessions   smallint not null check (target_sessions between 1 and 7),
  created_by        text not null default 'ai' check (created_by in ('ai','user')),
  ai_rationale      text,                     -- "Bạn hoàn thành 100%, tăng 5 phút mỗi buổi"
  source_review_id  uuid,                     -- FK thêm ở cuối file
  created_at        timestamptz not null default now()
);
create unique index training_plans_one_active_idx
  on training_plans(user_id, week_start) where status = 'active';

create table planned_sessions (
  id                    uuid primary key default gen_random_uuid(),
  plan_id               uuid not null references training_plans(id) on delete cascade,
  user_id               uuid not null references users(id) on delete cascade,
  template_id           uuid references workout_templates(id),
  scheduled_date        date not null,
  scheduled_time        time,
  title                 text not null,
  duration_min          smallint not null,
  variant               session_variant not null default 'normal',
  status                planned_status not null default 'planned',
  rescheduled_from_id   uuid references planned_sessions(id),
  adjusted_reason       text,                 -- 'checkin_tired','pain_shoulder','skip_busy'
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index planned_sessions_user_date_idx on planned_sessions(user_id, scheduled_date);

create table planned_session_items (
  id                   uuid primary key default gen_random_uuid(),
  planned_session_id   uuid not null references planned_sessions(id) on delete cascade,
  position             smallint not null,
  exercise_id          uuid not null references exercises(id),
  target_sets          smallint,
  target_reps          smallint,
  target_weight_kg     numeric(5,2),
  target_duration_sec  smallint,
  rest_sec             smallint not null default 60,
  unique (planned_session_id, position)
);

-- Buổi đã tập thật (có thể không nằm trong kế hoạch, ví dụ bản 5 phút)
create table workout_logs (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  planned_session_id  uuid references planned_sessions(id) on delete set null,
  started_at          timestamptz not null,
  ended_at            timestamptz,
  local_date          date not null,
  duration_sec        integer check (duration_sec >= 0),
  variant             session_variant not null default 'normal',
  rpe                 smallint check (rpe between 1 and 10),
  pain_areas          body_area[] not null default '{}',
  note                text,
  kcal_estimate       integer,
  counts_for_streak   boolean generated always as (coalesce(duration_sec, 0) >= 300) stored,  -- từ 5 phút
  created_at          timestamptz not null default now()
);
create index workout_logs_user_date_idx on workout_logs(user_id, local_date desc);

create table set_logs (
  id              uuid primary key default gen_random_uuid(),
  workout_log_id  uuid not null references workout_logs(id) on delete cascade,
  exercise_id     uuid not null references exercises(id),
  set_index       smallint not null,
  reps            smallint,                   -- số cuối cùng người dùng xác nhận
  weight_kg       numeric(5,2),
  duration_sec    smallint,
  is_pr           boolean not null default false,
  rep_source      rep_source not null default 'manual',
  reps_detected   smallint,                   -- camera đếm được (null nếu đếm tay)
  cv_config_id    uuid references exercise_cv_configs(id) on delete set null,
  avg_confidence  numeric(3,2) check (avg_confidence between 0 and 1),
  form_score      smallint check (form_score between 0 and 100),
  logged_at       timestamptz not null default now(),
  unique (workout_log_id, exercise_id, set_index)
);
create index set_logs_exercise_idx on set_logs(exercise_id);
-- Theo dõi độ chính xác: bài nào hay bị người dùng sửa số
create index set_logs_camera_idx on set_logs(cv_config_id) where rep_source <> 'manual';

-- Lỗi tư thế camera phát hiện ở từng lần
create table form_issues (
  id          uuid primary key default gen_random_uuid(),
  set_log_id  uuid not null references set_logs(id) on delete cascade,
  rep_index   smallint not null,
  issue_code  text not null,   -- 'shallow_depth','knee_cave','back_rounding','hips_sagging'
  severity    smallint not null check (severity between 1 and 3)
);
create index form_issues_set_idx on form_issues(set_log_id);

-- Kỷ lục hiện tại, cập nhật khi có set mới vượt kỷ lục
create table personal_records (
  user_id      uuid not null references users(id) on delete cascade,
  exercise_id  uuid not null references exercises(id),
  metric       text not null check (metric in ('max_weight','max_reps','max_duration','max_volume')),
  value        numeric(8,2) not null,
  set_log_id   uuid references set_logs(id) on delete set null,
  achieved_at  timestamptz not null,
  primary key (user_id, exercise_id, metric)
);

-- Check-in buổi sáng: mỗi người một lần mỗi ngày
create table daily_checkins (
  user_id     uuid not null references users(id) on delete cascade,
  local_date  date not null,
  energy      energy_level not null,
  sleep       sleep_bucket,
  created_at  timestamptz not null default now(),
  primary key (user_id, local_date)
);

-- =====================================================================
-- 4. CHỈ SỐ CƠ THỂ  (Tiến độ, F6 nhắc cân đo)
-- =====================================================================
create table body_measurements (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  measured_on   date not null,
  weight_kg     numeric(5,1),
  waist_cm      numeric(5,1),
  hip_cm        numeric(5,1),
  chest_cm      numeric(5,1),
  arm_cm        numeric(5,1),
  body_fat_pct  numeric(4,1),
  source        text not null default 'manual',   -- 'manual','apple_health','health_connect'
  created_at    timestamptz not null default now(),
  unique (user_id, measured_on)
);

-- Ảnh cơ thể: bucket riêng tư, chỉ chủ sở hữu đọc được
create table progress_photos (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  taken_on      date not null,
  pose          text not null check (pose in ('front','side','back')),
  storage_path  text not null,
  created_at    timestamptz not null default now()
);
create index progress_photos_user_idx on progress_photos(user_id, taken_on desc);

-- =====================================================================
-- 5. HỆ THỐNG ĐỘNG LỰC  (F3 bỏ buổi, F4 streak, F5 buddy, F6, F7)
-- =====================================================================

-- Một dòng cho mỗi tuần của mỗi người
create table weekly_streaks (
  user_id             uuid not null references users(id) on delete cascade,
  week_start          date not null,
  target_sessions     smallint not null,
  completed_sessions  smallint not null default 0,
  status              week_status not null default 'in_progress',
  closed_at           timestamptz,
  primary key (user_id, week_start)
);

-- Trạng thái tổng hợp để màn hình đọc nhanh
create table streak_state (
  user_id            uuid primary key references users(id) on delete cascade,
  current_weeks      integer not null default 0,
  best_weeks         integer not null default 0,
  freezes_available  smallint not null default 0 check (freezes_available between 0 and 2),
  last_closed_week   date,
  updated_at         timestamptz not null default now()
);

create table streak_freeze_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  week_start  date not null,
  kind        text not null check (kind in ('earned','used')),
  created_at  timestamptz not null default now()
);

-- Lý do bỏ buổi người dùng chọn: dữ liệu thật thay cho khảo sát
create table skip_reports (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  planned_session_id  uuid references planned_sessions(id) on delete set null,
  reason              skip_reason not null,
  note                text,
  action              skip_action not null default 'none',
  coach_message_id    uuid,                   -- FK thêm ở cuối file
  created_at          timestamptz not null default now()
);
create index skip_reports_reason_idx on skip_reports(reason, created_at);

-- Người dùng đang ở bậc nào của chuỗi nhắc quay lại
create table reengagement_state (
  user_id              uuid primary key references users(id) on delete cascade,
  stage                reengage_stage not null default 'active',
  last_workout_at      timestamptz,
  consecutive_missed   smallint not null default 0,
  stage_entered_at     timestamptz not null default now(),
  messages_in_stage    smallint not null default 0,
  updated_at           timestamptz not null default now()
);

create table buddy_invites (
  id           uuid primary key default gen_random_uuid(),
  inviter_id   uuid not null references users(id) on delete cascade,
  code         text not null unique,
  expires_at   timestamptz not null,
  accepted_by  uuid references users(id) on delete set null,
  accepted_at  timestamptz,
  created_at   timestamptz not null default now()
);

-- user_a < user_b để một cặp chỉ có một dòng
create table buddy_pairs (
  id                   uuid primary key default gen_random_uuid(),
  user_a               uuid not null references users(id) on delete cascade,
  user_b               uuid not null references users(id) on delete cascade,
  status               buddy_status not null default 'active',
  shared_streak_weeks  integer not null default 0,
  created_at           timestamptz not null default now(),
  ended_at             timestamptz,
  check (user_a < user_b)
);
create unique index buddy_pairs_active_idx on buddy_pairs(user_a, user_b) where status = 'active';

create table buddy_actions (
  id          uuid primary key default gen_random_uuid(),
  pair_id     uuid not null references buddy_pairs(id) on delete cascade,
  from_user   uuid not null references users(id) on delete cascade,
  to_user     uuid not null references users(id) on delete cascade,
  action      buddy_action not null,
  local_date  date not null,
  created_at  timestamptz not null default now()
);
-- "Nhắc bạn" tối đa 1 lần mỗi ngày
create unique index buddy_actions_one_nudge_idx
  on buddy_actions(from_user, to_user, local_date) where action = 'nudge';

create table achievements (
  code            text primary key,           -- 'sessions_10','first_pr','streak_4w','comeback'
  name_vi         text not null,
  description_vi  text not null,
  category        text not null,              -- 'sessions','strength','body','streak','buddy'
  threshold       integer
);

create table user_achievements (
  user_id           uuid not null references users(id) on delete cascade,
  achievement_code  text not null references achievements(code),
  earned_at         timestamptz not null default now(),
  context           jsonb not null default '{}',   -- {"exercise":"goblet-squat","value":8}
  shared_at         timestamptz,
  primary key (user_id, achievement_code)
);

create table weekly_reviews (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id) on delete cascade,
  week_start        date not null,
  sessions_done     smallint not null,
  sessions_target   smallint not null,
  total_minutes     integer not null default 0,
  avg_rpe           numeric(3,1),
  wins              jsonb not null default '[]',   -- [{"type":"pr","label":"Squat +2kg"}]
  improvement       text,
  recommendation    review_reco not null,
  proposed_plan_id  uuid references training_plans(id) on delete set null,
  decision          review_decision not null default 'pending',
  generated_at      timestamptz not null default now(),
  viewed_at         timestamptz,
  decided_at        timestamptz,
  unique (user_id, week_start)
);

-- =====================================================================
-- 6. DINH DƯỠNG  (F8)
-- =====================================================================
create table foods (
  id             uuid primary key default gen_random_uuid(),
  name_vi        text not null,               -- 'Cơm tấm sườn bì chả'
  aliases        text[] not null default '{}',
  category       text,
  serving_desc   text,                        -- '1 đĩa', '1 tô'
  serving_grams  numeric(6,1),
  kcal           numeric(6,1) not null,
  protein_g      numeric(6,1) not null default 0,
  carbs_g        numeric(6,1) not null default 0,
  fat_g          numeric(6,1) not null default 0,
  barcode        text unique,
  source         food_source not null default 'curated',
  verified       boolean not null default false,
  created_at     timestamptz not null default now()
);
create index foods_name_trgm_idx on foods using gin (name_vi gin_trgm_ops);

-- Mục tiêu theo thời gian (lưu lịch sử mỗi lần coach chỉnh)
create table nutrition_targets (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  effective_from  date not null,
  kcal            integer not null check (kcal >= 1200),   -- nam: app chặn thêm ở 1500
  protein_g       integer not null,
  carbs_g         integer not null,
  fat_g           integer not null,
  water_ml        integer not null default 2000,
  method          text not null default 'mifflin_st_jeor',
  created_at      timestamptz not null default now(),
  unique (user_id, effective_from)
);

create table meal_logs (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references users(id) on delete cascade,
  local_date     date not null,
  eaten_at       timestamptz not null default now(),
  meal           meal_type not null,
  method         input_method not null,
  photo_path     text,
  ai_confidence  numeric(3,2) check (ai_confidence between 0 and 1),
  kcal_min       integer,                     -- hiển thị dạng khoảng: 600–700
  kcal_max       integer,
  kcal           integer not null,            -- giá trị dùng để cộng tổng
  protein_g      numeric(6,1) not null default 0,
  carbs_g        numeric(6,1) not null default 0,
  fat_g          numeric(6,1) not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index meal_logs_user_date_idx on meal_logs(user_id, local_date);

create table meal_items (
  id            uuid primary key default gen_random_uuid(),
  meal_log_id   uuid not null references meal_logs(id) on delete cascade,
  food_id       uuid references foods(id) on delete set null,
  name          text not null,
  quantity      numeric(6,2) not null default 1,
  unit          text not null default 'phần',
  grams         numeric(6,1),
  kcal          numeric(6,1) not null,
  protein_g     numeric(6,1) not null default 0,
  carbs_g       numeric(6,1) not null default 0,
  fat_g         numeric(6,1) not null default 0,
  ai_suggested  boolean not null default true,
  user_edited   boolean not null default false   -- đo độ chính xác của AI
);

create table water_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  local_date  date not null,
  amount_ml   smallint not null check (amount_ml > 0),
  logged_at   timestamptz not null default now()
);
create index water_logs_user_date_idx on water_logs(user_id, local_date);

-- Mỗi lần gọi AI nhận diện: để cache theo hash ảnh và theo dõi chi phí
create table food_recognitions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  meal_log_id   uuid references meal_logs(id) on delete set null,
  image_sha256  text not null,
  model         text not null,
  raw_result    jsonb not null,
  latency_ms    integer,
  cost_usd      numeric(8,5),
  created_at    timestamptz not null default now()
);
create index food_recognitions_hash_idx on food_recognitions(image_sha256);

-- Giới hạn gói miễn phí (3 lượt chụp/ngày, ...)
create table daily_usage (
  user_id         uuid not null references users(id) on delete cascade,
  local_date      date not null,
  photo_scans     smallint not null default 0,
  coach_messages  smallint not null default 0,
  primary key (user_id, local_date)
);

-- =====================================================================
-- 7. AI COACH & THÔNG BÁO
-- =====================================================================
-- Mỗi người dùng một luồng chat duy nhất với coach
create table coach_messages (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  role                msg_role not null,
  content             text not null,
  card                jsonb,                  -- thẻ hành động: {"type":"session","session_id":"...","buttons":[...]}
  trigger             text,                   -- 'missed_2','weekly_review','user' ...
  related_session_id  uuid references planned_sessions(id) on delete set null,
  model               text,
  tokens_in           integer,
  tokens_out          integer,
  created_at          timestamptz not null default now()
);
create index coach_messages_user_idx on coach_messages(user_id, created_at desc);

-- Trí nhớ dài hạn của coach: "đau vai phải từ 26/9", "không ăn được hải sản"
create table coach_memory (
  user_id            uuid not null references users(id) on delete cascade,
  key                text not null,
  value              text not null,
  source_message_id  uuid references coach_messages(id) on delete set null,
  updated_at         timestamptz not null default now(),
  expires_at         timestamptz,
  primary key (user_id, key)
);

-- Nhật ký mọi thông báo: dùng để giới hạn 2 lần/ngày và đo tỷ lệ quay lại
create table notifications (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  type                notif_type not null,
  channel             notif_channel not null default 'push',
  local_date          date not null,
  scheduled_for       timestamptz not null,
  sent_at             timestamptz,
  opened_at           timestamptz,
  action              text,                   -- nút người dùng bấm: 'start_quick','reschedule','rest'
  related_session_id  uuid references planned_sessions(id) on delete set null,
  coach_message_id    uuid references coach_messages(id) on delete set null,
  ab_variant          text,
  created_at          timestamptz not null default now()
);
create index notifications_user_day_idx on notifications(user_id, local_date) where sent_at is not null;

-- =====================================================================
-- 8. ĐO LƯỜNG
-- =====================================================================
-- Khi lượng lớn nên chuyển sang PostHog/Amplitude hoặc partition theo tháng
create table events (
  id           bigint generated always as identity primary key,
  user_id      uuid references users(id) on delete set null,
  name         text not null,                 -- 'workout_completed','skip_reason',...
  properties   jsonb not null default '{}',
  occurred_at  timestamptz not null default now(),
  app_version  text
);
create index events_name_time_idx on events(name, occurred_at);

create table experiment_assignments (
  user_id         uuid not null references users(id) on delete cascade,
  experiment_key  text not null,              -- 'f3_ai_vs_fixed'
  variant         text not null,
  assigned_at     timestamptz not null default now(),
  primary key (user_id, experiment_key)
);

-- =====================================================================
-- Khóa ngoại vòng
-- =====================================================================
alter table training_plans
  add constraint training_plans_review_fk
  foreign key (source_review_id) references weekly_reviews(id) on delete set null;

alter table skip_reports
  add constraint skip_reports_message_fk
  foreign key (coach_message_id) references coach_messages(id) on delete set null;
