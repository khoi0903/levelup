/**
 * Hệ thống động lực: streak tuần, lý do bỏ buổi, buddy, tổng kết tuần, thông báo (một cổng gửi duy nhất)
 * và job định kỳ POST /jobs/tick (check-in, nhắc, chốt ngày, chốt tuần).
 * Endpoint: /streak, /skip-reports, /buddies/*, /reviews/*, /jobs/tick.
 *
 * Cấu trúc nhóm và tầng: backend/README.md. Luồng chi tiết: docs/04-backend-flow.html.
 */
package vn.levelup.engagement;
