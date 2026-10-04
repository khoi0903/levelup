import '../../../onboarding/domain/models/plan_models.dart';

class CheckinRequest {
  final String energy; // tired | normal | energized
  final String? sleep; // lt6 | h6_7 | h7_8 | gt8

  const CheckinRequest({
    required this.energy,
    this.sleep,
  });

  Map<String, dynamic> toJson() => {
        'energy': energy,
        if (sleep != null) 'sleep': sleep,
      };
}

class CheckinResponse {
  final String localDate;
  final String energy;
  final String? sleep;
  final bool adjusted;
  final SessionView? session;

  const CheckinResponse({
    required this.localDate,
    required this.energy,
    this.sleep,
    required this.adjusted,
    this.session,
  });

  factory CheckinResponse.fromJson(Map<String, dynamic> json) {
    return CheckinResponse(
      localDate: json['localDate']?.toString() ?? '',
      energy: json['energy']?.toString() ?? 'normal',
      sleep: json['sleep'] as String?,
      adjusted: json['adjusted'] == true,
      session: json['session'] != null
          ? SessionView.fromJson(json['session'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'localDate': localDate,
        'energy': energy,
        if (sleep != null) 'sleep': sleep,
        'adjusted': adjusted,
        if (session != null) 'session': session!.toJson(),
      };
}
