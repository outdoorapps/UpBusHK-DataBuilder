import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:up_bus_hk_data_builder/json/ctb_route.dart';
import 'package:up_bus_hk_data_builder/json/ctb_route_stop.dart';
import 'package:up_bus_hk_data_builder/json/ctb_stop.dart';
import 'package:up_bus_hk_data_builder/json/kmb_route.dart';
import 'package:up_bus_hk_data_builder/json/kmb_route_stop.dart';
import 'package:up_bus_hk_data_builder/json/kmb_stop.dart';
import 'package:up_bus_hk_data_builder/json/minibus_route_by_region.dart';
import 'package:up_bus_hk_data_builder/json/minibus_route_info.dart';
import 'package:up_bus_hk_data_builder/json/minibus_route_stop.dart';
import 'package:up_bus_hk_data_builder/json/minibus_stop.dart';
import 'package:up_bus_hk_data_builder/json/nlb_route.dart';
import 'package:up_bus_hk_data_builder/json/nlb_route_stop.dart';

part '../generated/network/api.g.dart';

@RestApi(baseUrl: 'https://data.etabus.gov.hk')
abstract class KmbApi {
  factory KmbApi(Dio dio, {String baseUrl}) = _KmbApi;

  @GET('/v1/transport/kmb/route')
  Future<KmbRouteResponse> getRoutes();

  @GET('/v1/transport/kmb/stop')
  Future<KmbStopResponse> getStops();

  @GET('/v1/transport/kmb/route-stop/{number}/{bound}/{serviceType}')
  Future<KmbRouteStopResponse> getRouteStops(
    @Path('number') String number,
    @Path('bound') String bound,
    @Path('serviceType') String serviceType,
  );
}

@RestApi(baseUrl: 'https://rt.data.gov.hk')
abstract class GovApi {
  factory GovApi(Dio dio, {String baseUrl}) = _GovApi;

  @GET('/v2/transport/citybus/route/ctb')
  Future<CtbRouteResponse> getCtbRoutes();

  @GET('/v2/transport/citybus/stop/{number}')
  Future<CtbStopResponse> getCtbStop(@Path('number') String number);

  @GET('/v2/transport/citybus/route-stop/ctb/{number}/{bound}')
  Future<CtbRouteStopResponse> getCtbRouteStops(
    @Path('number') String number,
    @Path('bound') String bound,
  );

  @GET('/v2/transport/nlb/route.php?action=list')
  Future<NlbRouteResponse> getNlbRoutes();

  @GET('/v2/transport/nlb/stop.php?action=list')
  Future<NlbRouteStopResponse> getNlbRouteStops(
    @Query('routeId') String routeId,
  );
}

@RestApi(baseUrl: 'https://data.etagmb.gov.hk')
abstract class MinibusApi {
  factory MinibusApi(Dio dio, {String baseUrl}) = _MinibusApi;

  @GET('/route')
  Future<MinibusRouteByRegionResponse> getRoutesByRegion();

  @GET('/route/{region}/{number}')
  Future<MinibusRouteOverviewResponse> getRouteOverview(
    @Path('region') String region,
    @Path('number') String number,
  );

  @GET('/route-stop/{routeId}/{routeSeq}')
  Future<MinibusRouteStopResponse> getRouteStops(
    @Path('routeId') int routeId,
    @Path('routeSeq') int routeSeq,
  );

  @GET('/stop/{stopId}')
  Future<MinibusStopResponse> getStop(@Path('stopId') int stopId);
}
