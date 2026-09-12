// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActionItem _$ActionItemFromJson(Map<String, dynamic> json) => ActionItem(
      id: json['id'] as String?,
      visitId: json['visitId'] as String?,
      propertyCode: json['propertyCode'] as String?,
      location: json['location'] as String?,
      category: json['category'] as String?,
      issue: json['issue'] as String?,
      priority: json['priority'] as String?,
      safetyHazard: json['safetyHazard'] as bool?,
      immediateControl: json['immediateControl'] as String?,
      responsibleParty: json['responsibleParty'] as String?,
      tenantUnit: json['tenantUnit'] as String?,
      leaseReview: json['leaseReview'] as bool?,
      actionOwner: json['actionOwner'] as String?,
      status: json['status'] as String?,
      targetCompletion: json['targetCompletion'] as String?,
      completionDate: json['completionDate'] as String?,
      verifiedBy: json['verifiedBy'] as String?,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
      costClassification: json['costClassification'] as String?,
      approvalStatus: json['approvalStatus'] as String?,
      vendorRef: json['vendorRef'] as String?,
      evidenceLink: json['evidenceLink'] as String?,
      notes: json['notes'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      requiresCapitalReview: json['requiresCapitalReview'] as bool?,
      open: json['open'] as bool?,
      overdue: json['overdue'] as bool?,
      createdAt: json['createdAt'],
    );

Map<String, dynamic> _$ActionItemToJson(ActionItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'visitId': instance.visitId,
      'propertyCode': instance.propertyCode,
      'location': instance.location,
      'category': instance.category,
      'issue': instance.issue,
      'priority': instance.priority,
      'safetyHazard': instance.safetyHazard,
      'immediateControl': instance.immediateControl,
      'responsibleParty': instance.responsibleParty,
      'tenantUnit': instance.tenantUnit,
      'leaseReview': instance.leaseReview,
      'actionOwner': instance.actionOwner,
      'status': instance.status,
      'targetCompletion': instance.targetCompletion,
      'completionDate': instance.completionDate,
      'verifiedBy': instance.verifiedBy,
      'estimatedCost': instance.estimatedCost,
      'costClassification': instance.costClassification,
      'approvalStatus': instance.approvalStatus,
      'vendorRef': instance.vendorRef,
      'evidenceLink': instance.evidenceLink,
      'notes': instance.notes,
      'mobileNumber': instance.mobileNumber,
      'requiresCapitalReview': instance.requiresCapitalReview,
      'open': instance.open,
      'overdue': instance.overdue,
      'createdAt': instance.createdAt,
    };
