import 'dart:io';

import 'package:dart_hk1980/dart_hk1980.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/isar/models/track.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_data_builder/builders/gov_feature_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/track_json.dart';
import 'package:up_bus_hk_data_builder/utils/ramer_douglas_peucker.dart';

class TrackBuilder {
  // Keep track of tracks used by BusRoutes
  static late final Set<String> _govRouteKeys;

  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await isar.writeTxn(() async => isar.tracks.clear());
    }

    // Get all distinct gov route keys
    final routes = await isar.busRoutes
        .where()
        .distinctByGovRouteKey()
        .findAll();

    _govRouteKeys = Set.unmodifiable(
      routes.map((e) => e.govRouteKey).whereType<String>().toSet(),
    );

    await _parseTracks();
    await _printStats();
  }

  static Future<void> _parseTracks() async {
    await GovFeatureParser.parseData<Track>(
      File(ProjectPath.busRoutesGeoJson),
      label: 'Parsing tracks',
      fromJson: (itemJson) {
        final feature = TrackFeature.fromJson(itemJson);

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
            .map((e) => Hk1980Converter.toWgs84(easting: e[0], northing: e[1]))
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

  static Future<void> _printStats() async {
    final tracks = await isar.tracks.where().findAll();

    final latLngCounts = <int>[];
    int bucketUnder100 = 0;
    int bucket100to200 = 0;
    int bucket200to500 = 0;
    int bucket500to1000 = 0;
    int bucket1000to1500 = 0;
    int bucket1500plus = 0;

    tracks.forEach((t) {
      final c = (t.flatCoordinates.length / 2).toInt();
      latLngCounts.add(c);

      if (c < 100)
        bucketUnder100++;
      else if (c <= 200)
        bucket100to200++;
      else if (c <= 500)
        bucket200to500++;
      else if (c <= 1000)
        bucket500to1000++;
      else if (c <= 1500)
        bucket1000to1500++;
      else
        bucket1500plus++;
    });
    final maxCount = latLngCounts.isEmpty
        ? 0
        : latLngCounts.reduce((a, b) => a > b ? a : b);
    final minCount = latLngCounts.isEmpty
        ? 0
        : latLngCounts.reduce((a, b) => a < b ? a : b);

    final maxTrack = tracks.firstWhere(
      (e) => e.flatCoordinates.length / 2 == maxCount,
    );
    await maxTrack.busRoutes.load();
    final maxRoute = maxTrack.busRoutes.first;

    final minTrack = tracks.firstWhere(
      (e) => e.flatCoordinates.length / 2 == minCount,
    );
    await minTrack.busRoutes.load();
    final minRoute = minTrack.busRoutes.first;

    final total = latLngCounts.reduce((a, b) => a + b);

    print('Track coordinate counts:');
    print('- <100: $bucketUnder100');
    print('- 100–200: $bucket100to200');
    print('- 200–500: $bucket200to500');
    print('- 500–1000: $bucket500to1000');
    print('- 1000–1500: $bucket1000to1500');
    print('- 1500+: $bucket1500plus');
    print('- Max: $maxCount, ($maxRoute)');
    print('- Min: $minCount, ($minRoute)');
    print('${tracks.length} tracks, $total coordinates');
  }
}
