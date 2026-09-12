// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardSummary _$DashboardSummaryFromJson(Map<String, dynamic> json) =>
    DashboardSummary(
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      reportsPending: (json['reportsPending'] as num?)?.toInt() ?? 0,
      reportsOverdue: (json['reportsOverdue'] as num?)?.toInt() ?? 0,
      openActions: (json['openActions'] as num?)?.toInt() ?? 0,
      openSafetyHazards: (json['openSafetyHazards'] as num?)?.toInt() ?? 0,
      overdueActions: (json['overdueActions'] as num?)?.toInt() ?? 0,
      capitalReviews: (json['capitalReviews'] as num?)?.toInt() ?? 0,
      estimatedOpenCost: (json['estimatedOpenCost'] as num?)?.toDouble() ?? 0,
      criticalOpen: (json['criticalOpen'] as num?)?.toInt() ?? 0,
      highOpen: (json['highOpen'] as num?)?.toInt() ?? 0,
      mediumOpen: (json['mediumOpen'] as num?)?.toInt() ?? 0,
      lowOpen: (json['lowOpen'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DashboardSummaryToJson(DashboardSummary instance) =>
    <String, dynamic>{
      'visits': instance.visits,
      'reportsPending': instance.reportsPending,
      'reportsOverdue': instance.reportsOverdue,
      'openActions': instance.openActions,
      'openSafetyHazards': instance.openSafetyHazards,
      'overdueActions': instance.overdueActions,
      'capitalReviews': instance.capitalReviews,
      'estimatedOpenCost': instance.estimatedOpenCost,
      'criticalOpen': instance.criticalOpen,
      'highOpen': instance.highOpen,
      'mediumOpen': instance.mediumOpen,
      'lowOpen': instance.lowOpen,
    };
