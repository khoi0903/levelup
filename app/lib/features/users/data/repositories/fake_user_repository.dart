import '../../../../core/api/api_exceptions.dart';
import '../../domain/models/me_response.dart';
import '../../domain/models/settings_request.dart';
import '../../domain/repositories/user_repository.dart';

class FakeUserRepository implements UserRepository {
  MeResponse? _meResponse;
  Exception? errorToThrow;
  Exception? deleteErrorToThrow;
  bool deleteAccountCalled = false;
  SettingsRequest? lastRequest;
  Map<String, dynamic>? lastJson;

  final List<({String bodyArea, String answer})> answeredPainFollowUps = [];
  PainFollowUpResponse? painFollowUpResponseToReturn;
  Exception? painFollowUpErrorToThrow;

  FakeUserRepository({
    MeResponse? meResponse,
    this.errorToThrow,
    this.deleteErrorToThrow,
    this.painFollowUpResponseToReturn,
    this.painFollowUpErrorToThrow,
  }) {
    _meResponse = meResponse;
  }

  @override
  Future<MeResponse> getMe() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return _meResponse ??
        const MeResponse(
          id: 'dev-user-id',
          displayName: 'Minh',
          timezone: 'Asia/Ho_Chi_Minh',
          localDate: '2026-10-03',
          weekStart: '2026-09-28',
          profile: UserProfile(
            goal: 'lose_fat',
            coachStyle: 'supportive',
            sessionMinutes: 15,
          ),
          streak: UserStreak(
            currentWeeks: 5,
            bestWeeks: 5,
            freezesAvailable: 1,
          ),
          settings: UserSettings(
            notifications: UserNotificationsSettings(
              pushEnabled: true,
              quietStart: '22:00',
              quietEnd: '07:00',
              maxPerDay: 2,
            ),
            sharing: UserSharingSettings(
              weight: false,
              measurements: false,
              photos: false,
              meals: false,
            ),
            availability: [],
          ),
          achievements: [],
        );
  }

  @override
  Future<MeResponse> updateSettings(SettingsRequest request) async {
    lastRequest = request;
    final json = request.toJson();
    lastJson = json;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    if (json.isEmpty) {
      throw const ApiException(
        code: 'NOTHING_TO_UPDATE',
        statusCode: 400,
      );
    }

    if (request.availability != null) {
      final days = <int>{};
      for (final a in request.availability!) {
        if (!days.add(a.weekday)) {
          throw const ApiException(
            code: 'DUPLICATE_WEEKDAY',
            statusCode: 400,
          );
        }
      }
    }

    final current = await getMe();

    final updatedProfile = UserProfile(
      goal: request.goal ?? current.profile?.goal,
      gender: current.profile?.gender,
      birthYear: current.profile?.birthYear,
      heightCm: current.profile?.heightCm,
      startWeightKg: current.profile?.startWeightKg,
      goalWeightKg: current.profile?.goalWeightKg,
      experience: current.profile?.experience,
      location: request.location ?? current.profile?.location,
      sessionMinutes: request.sessionMinutes ?? current.profile?.sessionMinutes,
      coachStyle: request.coachStyle ?? current.profile?.coachStyle,
      motivationReasons: current.profile?.motivationReasons ?? const [],
      motivationText: current.profile?.motivationText,
      equipment: request.equipment ?? current.profile?.equipment ?? const [],
      onboardingCompletedAt: current.profile?.onboardingCompletedAt,
    );

    final currentNotif = current.settings.notifications;
    final updatedNotifications = request.notifications == null
        ? currentNotif
        : UserNotificationsSettings(
            pushEnabled: request.notifications!.pushEnabled ?? currentNotif.pushEnabled,
            checkinTime: request.notifications!.checkinTime ?? currentNotif.checkinTime,
            preWorkoutMinutes: request.notifications!.preWorkoutMinutes ?? currentNotif.preWorkoutMinutes,
            quietStart: request.notifications!.quietStart ?? currentNotif.quietStart,
            quietEnd: request.notifications!.quietEnd ?? currentNotif.quietEnd,
            maxPerDay: request.notifications!.maxPerDay ?? currentNotif.maxPerDay,
            waterReminder: request.notifications!.waterReminder ?? currentNotif.waterReminder,
          );

    final currentSharing = current.settings.sharing;
    final updatedSharing = request.sharing == null
        ? currentSharing
        : UserSharingSettings(
            weight: request.sharing!.weight ?? currentSharing.weight,
            measurements: request.sharing!.measurements ?? currentSharing.measurements,
            photos: request.sharing!.photos ?? currentSharing.photos,
            meals: request.sharing!.meals ?? currentSharing.meals,
          );

    final updatedSettings = UserSettings(
      notifications: updatedNotifications,
      sharing: updatedSharing,
      availability: request.availability ?? current.settings.availability,
    );

    _meResponse = MeResponse(
      id: current.id,
      displayName: request.displayName ?? current.displayName,
      timezone: request.timezone ?? current.timezone,
      localDate: current.localDate,
      weekStart: current.weekStart,
      profile: updatedProfile,
      streak: current.streak,
      settings: updatedSettings,
      achievements: current.achievements,
    );

    return _meResponse!;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
    if (deleteErrorToThrow != null) {
      throw deleteErrorToThrow!;
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    _meResponse = null;
  }

  @override
  Future<PainFollowUpResponse> answerPainFollowUp(
    String bodyArea,
    String answer,
  ) async {
    answeredPainFollowUps.add((bodyArea: bodyArea, answer: answer));
    if (painFollowUpErrorToThrow != null) {
      throw painFollowUpErrorToThrow!;
    }
    if (painFollowUpResponseToReturn != null) {
      return painFollowUpResponseToReturn!;
    }

    final status = answer == 'gone'
        ? 'resolved'
        : (answer == 'worse' ? 'injury' : 'monitoring');
    final message = answer == 'gone'
        ? 'Vùng $bodyArea đã khỏi, tiếp tục tập luyện bình thường.'
        : (answer == 'worse'
            ? 'Vùng $bodyArea bị đau hơn, hãy nghỉ ngơi và đi khám chuyên khoa.'
            : 'Coach sẽ tiếp tục tránh bài tập tác động vào vùng $bodyArea.');

    if (_meResponse != null) {
      _meResponse = MeResponse(
        id: _meResponse!.id,
        displayName: _meResponse!.displayName,
        timezone: _meResponse!.timezone,
        localDate: _meResponse!.localDate,
        weekStart: _meResponse!.weekStart,
        profile: _meResponse!.profile,
        streak: _meResponse!.streak,
        settings: _meResponse!.settings,
        achievements: _meResponse!.achievements,
        todayCheckin: _meResponse!.todayCheckin,
        demoEnabled: _meResponse!.demoEnabled,
        isAdmin: _meResponse!.isAdmin,
        subscription: _meResponse!.subscription,
        productConfig: _meResponse!.productConfig,
        createdAt: _meResponse!.createdAt,
        referralRedeemEligible: _meResponse!.referralRedeemEligible,
        painFollowUps:
            _meResponse!.painFollowUps.where((p) => p.bodyArea != bodyArea).toList(),
        activeInjuries: answer == 'gone'
            ? _meResponse!.activeInjuries.where((i) => i.bodyArea != bodyArea).toList()
            : _meResponse!.activeInjuries,
      );
    }

    return PainFollowUpResponse(status: status, message: message);
  }
}
