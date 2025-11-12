import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/transit_route.dart';

part '../../generated/isar/models/minibus_route.g.dart';

@JsonSerializable(explicitToJson: true)
@Collection()
class MinibusRoute extends TransitRoute {
  static const String _normalMarker = 'normal';

  final int govRouteId;

  @enumerated
  final Region region;

  final String descriptionEn;
  final String descriptionChiT;
  final String descriptionChiS;

  MinibusRoute({
    required this.govRouteId,
    required this.region,
    required super.number,
    required super.bound,
    required this.descriptionEn,
    required this.descriptionChiT,
    required this.descriptionChiS,
    required super.originEn,
    required super.originChiT,
    required super.originChiS,
    required super.destEn,
    required super.destChiT,
    required super.destChiS,
    required super.fullFare,
    required super.stops,
  }) : super(
         routeId: toRouteId(govRouteId: govRouteId, bound: bound),
       );

  /// JSON serialization
  factory MinibusRoute.fromJson(Map<String, dynamic> json) =>
      _$MinibusRouteFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MinibusRouteToJson(this);

  static String toRouteId({required int govRouteId, required Bound bound}) {
    return '$govRouteId-${bound.name}';
  }

  // String getRouteDescriptions(SupportedLanguage language) => isNormal
  //     ? ''
  //     : switch (language) {
  //         SupportedLanguage.zh_Hant => descriptionChiT,
  //         SupportedLanguage.zh_Hans => descriptionChiS,
  //         SupportedLanguage.en => descriptionEn,
  //       }.trim();

  bool get isNormal => descriptionEn.toLowerCase().contains(_normalMarker);
}
