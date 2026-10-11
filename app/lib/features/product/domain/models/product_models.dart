class ReferralMilestone {
  final int friends;
  final int days;
  const ReferralMilestone(this.friends, this.days);
  factory ReferralMilestone.fromJson(Map<String, dynamic> j) =>
      ReferralMilestone(
        (j['friends'] as num).toInt(),
        (j['days'] as num).toInt(),
      );
  Map<String, dynamic> toJson() => {'friends': friends, 'days': days};
}

class ProductConfig {
  final bool proEnabled, referralEnabled;
  final int coachFreePerDay, coachProPerDay, photosFreePerDay, photosProPerDay;
  final int referralInviteeDays,
      monthlyPriceVnd,
      yearlyPriceVnd,
      trialDays,
      version;
  final List<ReferralMilestone> referralMilestones;
  const ProductConfig({
    this.proEnabled = false,
    this.referralEnabled = false,
    this.coachFreePerDay = 10,
    this.coachProPerDay = 100,
    this.photosFreePerDay = 3,
    this.photosProPerDay = 30,
    this.referralInviteeDays = 7,
    this.monthlyPriceVnd = 49000,
    this.yearlyPriceVnd = 399000,
    this.trialDays = 7,
    this.version = 0,
    this.referralMilestones = const [
      ReferralMilestone(1, 7),
      ReferralMilestone(3, 30),
      ReferralMilestone(10, 90),
    ],
  });
  factory ProductConfig.fromJson(Map<String, dynamic> j) => ProductConfig(
    proEnabled: j['proEnabled'] == true,
    referralEnabled: j['referralEnabled'] == true,
    coachFreePerDay: j['coachFreePerDay'] as int? ?? 10,
    coachProPerDay: j['coachProPerDay'] as int? ?? 100,
    photosFreePerDay: j['photosFreePerDay'] as int? ?? 3,
    photosProPerDay: j['photosProPerDay'] as int? ?? 30,
    referralInviteeDays: j['referralInviteeDays'] as int? ?? 7,
    monthlyPriceVnd: j['monthlyPriceVnd'] as int? ?? 49000,
    yearlyPriceVnd: j['yearlyPriceVnd'] as int? ?? 399000,
    trialDays: j['trialDays'] as int? ?? 7,
    version: j['version'] as int? ?? 0,
    referralMilestones:
        (j['referralMilestones'] as List?)
            ?.map(
              (m) => ReferralMilestone.fromJson(
                Map<String, dynamic>.from(m as Map),
              ),
            )
            .toList() ??
        const ProductConfig().referralMilestones,
  );
  Map<String, dynamic> toJson() => {
    'proEnabled': proEnabled,
    'referralEnabled': referralEnabled,
    'coachFreePerDay': coachFreePerDay,
    'coachProPerDay': coachProPerDay,
    'photosFreePerDay': photosFreePerDay,
    'photosProPerDay': photosProPerDay,
    'referralInviteeDays': referralInviteeDays,
    'referralMilestones': referralMilestones.map((m) => m.toJson()).toList(),
    'monthlyPriceVnd': monthlyPriceVnd,
    'yearlyPriceVnd': yearlyPriceVnd,
    'trialDays': trialDays,
    'version': version,
  };
}

class Subscription {
  final bool enabled;
  final String tier;
  final DateTime? expiresAt;
  final int coachPerDay, photosPerDay;
  const Subscription({
    this.enabled = false,
    this.tier = 'free',
    this.expiresAt,
    this.coachPerDay = 30,
    this.photosPerDay = 10,
  });
  factory Subscription.fromJson(Map<String, dynamic> j) {
    final limits = j['limits'] as Map? ?? {};
    return Subscription(
      enabled: j['enabled'] == true,
      tier: j['tier'] as String? ?? 'free',
      expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? ''),
      coachPerDay: limits['coachPerDay'] as int? ?? 30,
      photosPerDay: limits['photosPerDay'] as int? ?? 10,
    );
  }
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'tier': tier,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'limits': {'coachPerDay': coachPerDay, 'photosPerDay': photosPerDay},
  };
}

class ReferralView {
  final String code, link;
  final int successfulCount;
  final ReferralMilestone? nextMilestone;
  final List<ReferralMilestone> milestones, rewardsEarned;
  const ReferralView({
    required this.code,
    required this.link,
    this.successfulCount = 0,
    this.nextMilestone,
    this.milestones = const [],
    this.rewardsEarned = const [],
  });
  factory ReferralView.fromJson(Map<String, dynamic> j) => ReferralView(
    code: j['code'] as String,
    link: j['link'] as String,
    successfulCount: j['successfulCount'] as int? ?? 0,
    nextMilestone: j['nextMilestone'] == null
        ? null
        : ReferralMilestone.fromJson(
            Map<String, dynamic>.from(j['nextMilestone'] as Map),
          ),
    milestones: (j['milestones'] as List? ?? [])
        .map(
          (m) =>
              ReferralMilestone.fromJson(Map<String, dynamic>.from(m as Map)),
        )
        .toList(),
    rewardsEarned: (j['rewardsEarned'] as List? ?? [])
        .map(
          (m) =>
              ReferralMilestone.fromJson(Map<String, dynamic>.from(m as Map)),
        )
        .toList(),
  );
}
