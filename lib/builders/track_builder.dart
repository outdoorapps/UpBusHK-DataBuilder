import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/isar/models/track.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_data_builder/builders/gov_feature_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/track_json.dart';
import 'package:up_bus_hk_data_builder/utils/crs_2326.dart';
import 'package:up_bus_hk_data_builder/utils/ramer_douglas_peucker.dart';

class TrackBuilder {
  static late final Set<String> _govRouteKeys;

  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await isar.writeTxn(() async => isar.tracks.clear());
    }
    await Crs2326.init();

    // Get all distinct gov route keys
    final routes = await isar.busRoutes
        .where()
        .distinctByGovRouteKey()
        .findAll();

    _govRouteKeys = Set.unmodifiable(
      routes.map((e) => e.govRouteKey).whereType<String>().toSet(),
    );

    await _parseTracks();

    // todo print Stats for tracks
  }

  static Future<void> _parseTracks() async {
    await GovFeatureParser.parseData<Track>(
      File(ProjectPath.busRoutesGeoJsonPath),
      label: 'Parsing tracks',
      fromJson: (itemJson) {
        final feature = TrackFeature.fromJson(itemJson);

        // Skip track not used be any route
        if (!_govRouteKeys.contains(feature.properties.key)) return null;

        final govRouteKey = Track.getGovRouteKey(
          feature.properties.routeId,
          feature.properties.routeSeq,
        );

        final hk1980Coordinates = feature.geometry.coordinates
            .expand((e) => e)
            .toList();
        final hk1980Track = RamerDouglasPeucker.simplify(hk1980Coordinates);

        final flatCoordinates = hk1980Track
            .map((e) => Crs2326.convert(e[0], e[1]))
            .expand((e) => e)
            .toList();

        return Track(
          objectId: feature.properties.objectId,
          govRouteKey: govRouteKey,
          flatCoordinates: flatCoordinates,
        );
      },
      writeToIsar: (batch) async {
        await isar.writeTxn(() async {
          for (final track in batch) {
            await isar.tracks.put(track);

            // Now establish the link
            final route = await isar.busRoutes
                .where()
                .govRouteKeyEqualTo(track.govRouteKey)
                .findFirst();
            if (route != null) {
              route.track.value = track;
              await route.track.save();
            }
          }
        });
      },
      batchSize: 10,
    );
  }
}
