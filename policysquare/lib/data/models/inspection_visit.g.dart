// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection_visit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InspectionVisit _$InspectionVisitFromJson(Map<String, dynamic> json) =>
    InspectionVisit(
      id: json['id'] as String?,
      propertyCode: json['propertyCode'] as String?,
      visitDate: json['visitDate'] as String?,
      inspector: json['inspector'] as String?,
      inspectionType: json['inspectionType'] as String?,
      weatherConditions: json['weatherConditions'] as String?,
      reportDueDate: json['reportDueDate'] as String?,
      reportSentDate: json['reportSentDate'] as String?,
      sentTo: json['sentTo'] as String?,
      reportLink: json['reportLink'] as String?,
      areasInspected: json['areasInspected'] as String?,
      overallCondition: json['overallCondition'] as String?,
      operationsSummary: json['operationsSummary'] as String?,
      revenueExpenseIssues: json['revenueExpenseIssues'] as String?,
      immediateActions: json['immediateActions'] as String?,
      decisionsRequired: json['decisionsRequired'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      reportStatus: json['reportStatus'] as String?,
      createdAt: json['createdAt'],
    );

Map<String, dynamic> _$InspectionVisitToJson(InspectionVisit instance) =>
    <String, dynamic>{
      'id': instance.id,
      'propertyCode': instance.propertyCode,
      'visitDate': instance.visitDate,
      'inspector': instance.inspector,
      'inspectionType': instance.inspectionType,
      'weatherConditions': instance.weatherConditions,
      'reportDueDate': instance.reportDueDate,
      'reportSentDate': instance.reportSentDate,
      'sentTo': instance.sentTo,
      'reportLink': instance.reportLink,
      'areasInspected': instance.areasInspected,
      'overallCondition': instance.overallCondition,
      'operationsSummary': instance.operationsSummary,
      'revenueExpenseIssues': instance.revenueExpenseIssues,
      'immediateActions': instance.immediateActions,
      'decisionsRequired': instance.decisionsRequired,
      'mobileNumber': instance.mobileNumber,
      'reportStatus': instance.reportStatus,
      'createdAt': instance.createdAt,
    };
