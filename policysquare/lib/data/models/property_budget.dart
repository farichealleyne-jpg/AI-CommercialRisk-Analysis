import 'package:json_annotation/json_annotation.dart';

part 'property_budget.g.dart';

@JsonSerializable()
class BudgetLineItem {
  String category;
  String description;
  double estimatedCost;
  String priority; // Low, Medium, High

  BudgetLineItem({
    required this.category,
    required this.description,
    required this.estimatedCost,
    this.priority = 'Medium',
  });

  factory BudgetLineItem.fromJson(Map<String, dynamic> json) =>
      _$BudgetLineItemFromJson(json);
  Map<String, dynamic> toJson() => _$BudgetLineItemToJson(this);
}

@JsonSerializable()
class PropertyBudget {
  String? id;
  String? mobileNumber;
  String? propertyAddress;
  String? riskAssessmentId;
  String? status; // DRAFT, FINALIZED
  double? totalEstimatedCost;
  String? data; // JSON-encoded List<BudgetLineItem>
  dynamic createdAt;

  PropertyBudget({
    this.id,
    this.mobileNumber,
    this.propertyAddress,
    this.riskAssessmentId,
    this.status,
    this.totalEstimatedCost,
    this.data,
    this.createdAt,
  });

  factory PropertyBudget.fromJson(Map<String, dynamic> json) =>
      _$PropertyBudgetFromJson(json);
  Map<String, dynamic> toJson() => _$PropertyBudgetToJson(this);
}
