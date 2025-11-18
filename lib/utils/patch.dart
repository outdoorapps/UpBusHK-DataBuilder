import 'package:up_bus_hk_core/isar/models/lat_lng.dart';

class Patch {
  static final stopIdToLatLng = {
    '152': LatLng(lat: 22.501070, long: 113.945650),
  };

// "60C1F7910C07C52B" for 115,I,1 KOWLOON CITY FERRY BUS TERMINUS (KC949), need no matching with a CTB stop,
// KMB included two consecutive terminating stops. This, the last one, was redundant.
// todo remove 60C1F7910C07C52B for 115 kmb 1 inbound


// "F0A8A596641FFC5A" for 170,I SHA TIN STATION BUS TERMINUS (ST941), need no matching with a CTB stop,
// KMB included two consecutive terminating stops. This, the last one, was redundant.
  // todo remove F0A8A596641FFC5A for 170 kmb inbound

// todo 107P I 1 use CTB as primary source
  // No match for StopID:69EB1A85EBBBA550, (107P,I,1)
}
