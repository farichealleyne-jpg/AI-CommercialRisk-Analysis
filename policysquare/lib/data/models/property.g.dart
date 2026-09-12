// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'property.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Property _$PropertyFromJson(Map<String, dynamic> json) => Property(
      code: json['code'] as String?,
      name: json['name'] as String?,
      addressLine: json['addressLine'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'],
    );

Map<String, dynamic> _$PropertyToJson(Property instance) => <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'addressLine': instance.addressLine,
      'city': instance.city,
      'region': instance.region,
      'mobileNumber': instance.mobileNumber,
      'status': instance.status,
      'notes': instance.notes,
      'createdAt': instance.createdAt,
    };
