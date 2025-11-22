import 'package:json_annotation/json_annotation.dart';

part '../generated/json/nlb_route.g.dart';

/// New Lantao Bus (NLB) Route Response
@JsonSerializable(explicitToJson: true)
class NlbRouteResponse {
  final List<NlbRoute> routes;

  NlbRouteResponse({required this.routes});

  factory NlbRouteResponse.fromJson(Map<String, dynamic> json) =>
      _$NlbRouteResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NlbRouteResponseToJson(this);
}

/// New Lantao Bus (NLB) Route
@JsonSerializable()
class NlbRoute {
  final String routeId;

  @JsonKey(name: 'routeNo')
  final String number;

  @JsonKey(name: 'routeName_c')
  final String routeNameC;

  @JsonKey(name: 'routeName_s')
  final String routeNameS;

  @JsonKey(name: 'routeName_e')
  final String routeNameE;

  final int overnightRoute;
  final int specialRoute;

  NlbRoute({
    required this.routeId,
    required this.number,
    required this.routeNameC,
    required this.routeNameS,
    required this.routeNameE,
    required this.overnightRoute,
    required this.specialRoute,
  });

  factory NlbRoute.fromJson(Map<String, dynamic> json) =>
      _$NlbRouteFromJson(json);

  Map<String, dynamic> toJson() => _$NlbRouteToJson(this);
}
