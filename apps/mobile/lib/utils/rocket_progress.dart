const List<int> rocketStageTargets = <int>[
  8000000,
  15000000,
  30000000,
  50000000,
  90000000,
  150000000,
  200000000,
  250000000,
  350000000,
  500000000,
];

/// Calculates Rocket progress against cumulative room gift totals.
///
/// Each target is a milestone total, not an amount to add to the previous
/// milestone. Values returned here drive both the Rocket panel and its tests.
Map<String, num> calculateRocketProgress(int total) {
  final safeTotal = total < 0 ? 0 : total;
  var completed = 0;
  for (final target in rocketStageTargets) {
    if (safeTotal >= target) {
      completed++;
    } else {
      break;
    }
  }

  final allComplete = completed == rocketStageTargets.length;
  final currentTarget = allComplete
      ? rocketStageTargets.last
      : rocketStageTargets[completed];
  final currentProgress = allComplete ? rocketStageTargets.last : safeTotal;
  final percent = allComplete
      ? 1.0
      : (currentProgress / currentTarget).clamp(0.0, 1.0);

  return <String, num>{
    'completed': completed,
    'current_progress': currentProgress,
    'current_target': currentTarget,
    'percent': percent,
  };
}
