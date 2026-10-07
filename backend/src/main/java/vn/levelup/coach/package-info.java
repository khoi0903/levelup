/**
 * AI coach: chat, đề xuất hành động (AI không ghi thẳng database, backend kiểm tra rồi mới ghi).
 * Gọi AI chỉ qua {@code ai.AiClient}. Endpoint: GET/POST /coach/messages, POST /coach/messages/stream, POST …/actions/apply.
 *
 * Cấu trúc nhóm và tầng: backend/README.md. Luồng chi tiết: docs/04-backend-flow.html.
 */
package vn.levelup.coach;
