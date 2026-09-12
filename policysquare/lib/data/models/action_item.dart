import 'package:json_annotation/json_annotation.dart';

part 'action_item.g.dart';

@JsonSerializable()
class ActionItem {
  String? id;
  String? visitId;
  String? propertyCode;
  String? location;
  String? category;
  String? issue;
  String? priority; // CRITICAL, HIGH, MEDIUM, LOW
  bool? safetyHazard;
  String? immediateControl;
  String? responsibleParty;
  String? tenantUnit;
  bool? leaseReview;
  String? actionOwner;
  String? status; // OPEN, QUOTE_REQUESTED, APPROVED, IN_PROGRESS, VERIFIED, CLOSED
  String? targetCompletion;
  String? completionDate;
  String? verifiedBy;
  double? estimatedCost;
  String? costClassification; // OPERATING, CAPITAL
  String? approvalStatus; // NOT_REQUIRED, PENDING, APPROVED, DECLINED
  String? vendorRef;
  String? evidenceLink;
  String? notes;
  String? mobileNumber;

  /// Derived server-side.
  bool? requiresCapitalReview;
  bool? open;
  bool? overdue;
  dynamic createdAt;

  ActionItem({
    this.id,
    this.visitId,
    this.propertyCode,
    this.location,
    this.category,
    this.issue,
    this.priority,
    this.safetyHazard,
    this.immediateControl,
    this.responsibleParty,
    this.tenantUnit,
    this.leaseReview,
    this.actionOwner,
    this.status,
    this.targetCompletion,
    this.completionDate,
    this.verifiedBy,
    this.estimatedCost,
    this.costClassification,
    this.approvalStatus,
    this.vendorRef,
    this.evidenceLink,
    this.notes,
    this.mobileNumber,
    this.requiresCapitalReview,
    this.open,
    this.overdue,
    this.createdAt,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) =>
      _$ActionItemFromJson(json);
  Map<String, dynamic> toJson() => _$ActionItemToJson(this);
}
