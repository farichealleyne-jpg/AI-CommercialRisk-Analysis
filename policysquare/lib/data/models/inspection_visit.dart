import 'package:json_annotation/json_annotation.dart';

part 'inspection_visit.g.dart';

@JsonSerializable()
class InspectionVisit {
  String? id;
  String? propertyCode;
  String? visitDate;
  String? inspector;
  String? inspectionType;
  String? weatherConditions;
  String? reportDueDate;
  String? reportSentDate;
  String? sentTo;
  String? reportLink;
  String? areasInspected;
  String? overallCondition;
  String? operationsSummary;
  String? revenueExpenseIssues;
  String? immediateActions;
  String? decisionsRequired;
  String? mobileNumber;

  /// Derived server-side against the PMA reporting window.
  String? reportStatus; // PENDING, SENT, OVERDUE
  dynamic createdAt;

  InspectionVisit({
    this.id,
    this.propertyCode,
    this.visitDate,
    this.inspector,
    this.inspectionType,
    this.weatherConditions,
    this.reportDueDate,
    this.reportSentDate,
    this.sentTo,
    this.reportLink,
    this.areasInspected,
    this.overallCondition,
    this.operationsSummary,
    this.revenueExpenseIssues,
    this.immediateActions,
    this.decisionsRequired,
    this.mobileNumber,
    this.reportStatus,
    this.createdAt,
  });

  factory InspectionVisit.fromJson(Map<String, dynamic> json) =>
      _$InspectionVisitFromJson(json);
  Map<String, dynamic> toJson() => _$InspectionVisitToJson(this);
}
