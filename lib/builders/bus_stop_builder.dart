import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/isar/models/bus_stop.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/network/data_services.dart';

class BusStopBuilder {
  static Future<List<BusStop>> buildKmbStops() async {
    final stops = await DataServices.getKmbStops();
    return stops.map((e) {
      return BusStop(
        company: Company.KMB,
        stopId: e.stop,
        engName: e.nameEn,
        chiTName: e.nameTc,
        chiSName: e.nameSc,
        coordinate: LatLng(
          lat: double.tryParse(e.lat) ?? 0,
          long: double.tryParse(e.lng) ?? 0,
        ),
      );
    }).toList();
  }

  static Future<List<BusStop>> buildCtbStops() async {
    return [];
  }

  static Future<List<BusStop>> buildNlbStops() async {
    return [];
  }

  static Future<List<BusStop>> buildMtrbStops() async {
    return [];
  }
}
