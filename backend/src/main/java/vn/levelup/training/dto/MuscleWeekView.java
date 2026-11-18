package vn.levelup.training.dto;

import java.util.Map;

/**
 * GET /me/muscles/week: số hiệp đã tập trong tuần theo nhóm cơ.
 * muscles luôn đủ 7 khoá chest, back, shoulders, arms, abs, glutes, legs (chưa tập là 0).
 */
public record MuscleWeekView(String weekStart, Map<String, Integer> muscles) {}
