import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/review_models.dart';
import '../../domain/repositories/review_repository.dart';

class FakeReviewRepository implements ReviewRepository {
  WeeklyReviewView? reviewView;
  PlanView? decidedPlan;
  Exception? errorToThrow;
  ReviewDecisionRequest? lastDecisionRequest;
  String? lastDecidedReviewId;

  FakeReviewRepository({
    this.reviewView,
    this.decidedPlan,
    this.errorToThrow,
  });

  @override
  Future<WeeklyReviewView> getLatestReview() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return reviewView ??
        WeeklyReviewView(
          id: 'review-w1',
          weekStart: '2026-09-28',
          sessionsDone: 3,
          sessionsTarget: 3,
          completionPct: 100,
          totalMinutes: 45,
          avgRpe: 7.2,
          recommendation: 'increase',
          win: 'Hoàn thành 100% mục tiêu tuần đầu tiên!',
          wins: const [
            ReviewWin(type: 'streak', label: 'Duy trì streak 1 tuần'),
            ReviewWin(type: 'pr', label: 'Kỷ lục 15 lần Squat liên tục'),
          ],
          improvement: 'Giữ đều thời gian nghỉ giữa các hiệp sẽ giúp bạn bền sức hơn.',
          nextWeekSummary: 'Tuần tới: tăng lên 4 buổi, mỗi buổi 15 phút.',
          weightChangeKg: -0.4,
          decision: 'pending',
          source: 'rules',
          generatedAt: DateTime.now(),
          plan: const PlanView(
            id: 'plan-w2',
            weekStart: '2026-10-05',
            status: 'draft',
            targetSessions: 4,
            sessions: [
              SessionView(
                id: 's-w2-1',
                scheduledDate: '2026-10-05',
                scheduledTime: '18:30',
                title: 'Toàn thân + Lưng',
                durationMin: 15,
                status: 'planned',
              ),
            ],
          ),
        );
  }

  @override
  Future<PlanView> submitDecision(String reviewId, ReviewDecisionRequest request) async {
    lastDecidedReviewId = reviewId;
    lastDecisionRequest = request;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (reviewView != null) {
      reviewView = WeeklyReviewView(
        id: reviewView!.id,
        weekStart: reviewView!.weekStart,
        sessionsDone: reviewView!.sessionsDone,
        sessionsTarget: reviewView!.sessionsTarget,
        completionPct: reviewView!.completionPct,
        totalMinutes: reviewView!.totalMinutes,
        avgRpe: reviewView!.avgRpe,
        recommendation: reviewView!.recommendation,
        win: reviewView!.win,
        wins: reviewView!.wins,
        improvement: reviewView!.improvement,
        nextWeekSummary: reviewView!.nextWeekSummary,
        weightChangeKg: reviewView!.weightChangeKg,
        decision: request.decision,
        source: reviewView!.source,
        generatedAt: reviewView!.generatedAt,
        plan: reviewView!.plan,
      );
    }
    return decidedPlan ??
        const PlanView(
          id: 'plan-w2',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 4,
          sessions: [
            SessionView(
              id: 's-w2-1',
              scheduledDate: '2026-10-05',
              scheduledTime: '18:30',
              title: 'Toàn thân + Lưng',
              durationMin: 15,
              status: 'planned',
            ),
          ],
        );
  }
}
