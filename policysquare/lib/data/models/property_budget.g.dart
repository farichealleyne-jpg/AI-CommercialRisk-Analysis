// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'property_budget.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BudgetLineItem _$BudgetLineItemFromJson(Map<String, dynamic> json) =>
    BudgetLineItem(
      category: json['category'] as String,
      description: json['description'] as String,
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      priority: json['priority'] as String? ?? 'Medium',
    );

Map<String, dynamic> _$BudgetLineItemToJson(BudgetLineItem instance) =>
    <String, dynamic>{
      'category': instance.category,
      'description': instance.description,
      'estimatedCost': instance.estimatedCost,
      'priority': instance.priority,
    };

PropertyBudget _$PropertyBudgetFromJson(Map<String, dynamic> json) =>
    PropertyBudget(
      id: json['id'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      propertyAddress: json['propertyAddress'] as String?,
      riskAssessmentId: json['riskAssessmentId'] as String?,
      status: json['status'] as String?,
      totalEstimatedCost: (json['totalEstimatedCost'] as num?)?.toDouble(),
      data: json['data'] as String?,
      createdAt: json['createdAt'],
    );

Map<String, dynamic> _$PropertyBudgetToJson(PropertyBudget instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mobileNumber': instance.mobileNumber,
      'propertyAddress': instance.propertyAddress,
      'riskAssessmentId': instance.riskAssessmentId,
      'status': instance.status,
      'totalEstimatedCost': instance.totalEstimatedCost,
      'data': instance.data,
      'createdAt': instance.createdAt,
    };
