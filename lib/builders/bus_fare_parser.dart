import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:up_bus_hk_core/isar/data_builder_models/bus_fare.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

class BusFareParser {
  static const _batchSize = 10000;
  final _writeController = StreamController<List<BusFare>>(sync: true);

  /// Parse bus fare data from FARE_BUS.xml and write to Isar
  Future<void> parseBusFareData() async {
    // Clear existing data
    await builderIsar.writeTxn(() => builderIsar.busFares.clear());

    final file = File(ProjectPaths.busFarePath);
    final batch = <BusFare>[];
    final writeFuture = _processWriteQueue(_writeController.stream);

    final tracker = ProgressTracker(label: 'Parsing bus fare');
    await file
        .openRead()
        .transform(utf8.decoder)
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents((event) => event.name == 'FARE')
        .toXmlNodes()
        .expand((nodes) => nodes)
        .forEach((e) {
          final govBusRouteId = int.tryParse(
            e.getElement('ROUTE_ID')?.innerText ?? '',
          );
          final routeSeq = int.tryParse(
            e.getElement('ROUTE_SEQ')?.innerText ?? '',
          );
          final onSeq = int.tryParse(e.getElement('ON_SEQ')?.innerText ?? '');
          final offSeq = int.tryParse(e.getElement('OFF_SEQ')?.innerText ?? '');
          final fare = double.tryParse(e.getElement('PRICE')?.innerText ?? '');

          if (govBusRouteId != null &&
              routeSeq != null &&
              onSeq != null &&
              offSeq != null &&
              fare != null) {
            final busFare = BusFare(
              govBusRouteId: govBusRouteId,
              routeSeq: routeSeq,
              onSeq: onSeq,
              offSeq: offSeq,
              fare: fare,
            );
            batch.add(busFare);
            if (batch.length >= _batchSize) {
              _writeController.add(List<BusFare>.from(batch));
              batch.clear();
            }
            tracker.increment();
          }
        });

    if (batch.isNotEmpty) _writeController.add(List<BusFare>.from(batch));
    _writeController.close();
    await writeFuture;
    tracker.finish();
  }

  Future<void> _processWriteQueue(Stream<List<BusFare>> stream) async {
    await for (final batch in stream) {
      await builderIsar.writeTxn(() => builderIsar.busFares.putAll(batch));
    }
  }
}
