class PlanHealthService {
  PlanHealthService._();

  static String getHealthStatus({
    required double actual,
    required double expected,
  }) {
    final double diff = actual - expected;
    final double base = expected == 0.0 ? 1.0 : expected;
    final double pct = (diff / base) * 100.0;
    if (pct > 5.0) {
      return 'ahead';
    } else if (pct < -5.0) {
      return 'behind';
    } else {
      return 'on_track';
    }
  }
}
