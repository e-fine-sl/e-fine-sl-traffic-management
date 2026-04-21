class DailyStatsModel {
  final int finesTodayCount;
  final num finesTodayAmount;
  final int vehiclesCheckedToday;

  DailyStatsModel({
    required this.finesTodayCount,
    required this.finesTodayAmount,
    required this.vehiclesCheckedToday,
  });

  factory DailyStatsModel.fromJson(Map<String, dynamic> json) {
    return DailyStatsModel(
      finesTodayCount: json['finesTodayCount'] ?? 0,
      finesTodayAmount: json['finesTodayAmount'] ?? 0,
      vehiclesCheckedToday: json['vehiclesCheckedToday'] ?? 0,
    );
  }
}

class HqAlertModel {
  final String title;
  final String message;
  final String severity;

  HqAlertModel({
    required this.title,
    required this.message,
    required this.severity,
  });

  factory HqAlertModel.fromJson(Map<String, dynamic> json) {
    return HqAlertModel(
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'high',
    );
  }
}
