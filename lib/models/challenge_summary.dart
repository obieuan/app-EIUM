class ChallengeSummary {
  final int hurraTotal;
  final int antorchaTotal;
  final int weeklyRequirement;
  final bool permissionDenied;

  const ChallengeSummary({
    required this.hurraTotal,
    required this.antorchaTotal,
    required this.weeklyRequirement,
    required this.permissionDenied,
  });

  factory ChallengeSummary.empty({bool permissionDenied = false}) {
    return ChallengeSummary(
      hurraTotal: 0,
      antorchaTotal: 0,
      weeklyRequirement: 1,
      permissionDenied: permissionDenied,
    );
  }
}
