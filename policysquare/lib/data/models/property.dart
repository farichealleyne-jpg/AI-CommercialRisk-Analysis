import 'package:json_annotation/json_annotation.dart';

part 'property.g.dart';

@JsonSerializable()
class Property {
  String? code;
  String? name;
  String? addressLine;
  String? city;
  String? region;
  String? mobileNumber;
  String? status; // ACTIVE, INACTIVE
  String? notes;
  dynamic createdAt;

  Property({
    this.code,
    this.name,
    this.addressLine,
    this.city,
    this.region,
    this.mobileNumber,
    this.status,
    this.notes,
    this.createdAt,
  });

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get displayAddress {
    final parts = [addressLine, city, region]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? 'No address recorded' : parts.join(', ');
  }

  factory Property.fromJson(Map<String, dynamic> json) =>
      _$PropertyFromJson(json);
  Map<String, dynamic> toJson() => _$PropertyToJson(this);
}
