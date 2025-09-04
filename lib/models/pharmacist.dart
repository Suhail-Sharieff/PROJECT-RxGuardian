
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pharmacist.freezed.dart';
part 'pharmacist.g.dart'; // Ensure JSON serialization works
//flutter packages pub run build_runner build
@freezed
abstract class Pharmacist  with _$Pharmacist{
  @JsonSerializable(explicitToJson: true)
  factory Pharmacist(
      {
        @JsonKey(name: 'pharmacist_id', includeIfNull: false) int? id,
        @JsonKey(name: 'name',includeIfNull: false) String? name,
        @JsonKey(name:'dob',includeIfNull: false) String? dob,
        @JsonKey(name: 'address',includeIfNull: false) String? address,
        @JsonKey(name: 'phone',includeIfNull: false) String? phone,
        @JsonKey(name: 'email',includeIfNull: false) String? email,
        @Default('no-accessToken-provided')@JsonKey(name:'accessToken', includeIfNull: false) String? accessToken,
        @Default('no-refreshToken-provided')@JsonKey(name:'refreshToken', includeIfNull: false) String? refreshToken,
      }
      )=_Pharmacist;
  factory Pharmacist.fromJson(Map<String, dynamic> json) => _$PharmacistFromJson(json);
}