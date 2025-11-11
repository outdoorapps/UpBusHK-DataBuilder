import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/isar/models/company_bus_route.dart';
import 'package:upbushk_data_builder/network/data_services.dart';

class CompanyRouteBuilder {
  Future<List<CompanyBusRoute>> getKmbRoutes() async {
    final kmbRoutes = await DataServices.getKmbRoutes();
    return await Future.wait(
      kmbRoutes.map((e) async {
        final stops = await DataServices.getKmbRouteStops(
          e.route,
          e.bound.kmbLabel,
          e.serviceType,
        );
        return CompanyBusRoute(
          company: Company.KMB,
          number: e.route,
          bound: e.bound,
          originEn: e.origEn,
          originChiT: e.origTc,
          originChiS: e.origSc,
          destEn: e.destEn,
          destChiT: e.destTc,
          destChiS: e.destSc,
          serviceType: int.tryParse(e.serviceType),
          nlbRouteId: null,
          stops: stops.map((e) => e.stopId).toList(),
        );
      }),
    );
  }

  // Future<List<CompanyBusRoute>> getCtbRoutes() async {
  //   final routes = await DataServices.getCtbRoutes();
  //   return await Future.wait(routes.map((e){
  //
  //
  //   }));
  // }

  // Future<List<CompanyBusRoute>> getNlbRoutes() async {
  //   final routes = await DataServices.getNlbRoutes();
  //   return await Future.wait();
  // }
}
