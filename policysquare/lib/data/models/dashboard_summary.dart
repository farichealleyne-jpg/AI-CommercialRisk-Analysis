import 'package:json_annotation/json_annotation.dart';

part 'dashboard_summary.g.dart';

@JsonSerializable()
class DashboardSummary {
  int visits;
  int reportsPending;
  int reportsOverdue;
  int openActions;
  int openSafetyHazards;
  int overdueActions;
  int capitalReviews;
  double estimatedOpenCost;
  int criticalOpen;
  int highOpen;
  int mediumOpen;
  int lowOpen;

  DashboardSummary({
    this.visits = 0,
    this.reportsPending = 0,
    this.reportsOverdue = 0,
    this.openActions = 0,
    this.openSafetyHazards = 0,
    this.overdueActions = 0,
    this.capitalReviews = 0,
    this.estimatedOpenCost = 0,
    this.criticalOpen = 0,
    this.highOpen = 0,
    this.mediumOpen = 0,
    this.lowOpen = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardSummaryToJson(this);
}
