import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/bus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/utils/utils.dart';

abstract class TransitRoute implements Comparable<TransitRoute> {
  @JsonKey(includeFromJson: false, includeToJson: false)
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  final String routeId;
  final String number;
  @enumerated
  final Bound bound;
  final String originEn;
  final String originChiT;
  final String destEn;
  final String destChiT;
  final double? fullFare;
  final List<String> stops;

  TransitRoute({
    required this.routeId,
    required this.number,
    required this.bound,
    required this.originEn,
    required this.originChiT,
    required this.destEn,
    required this.destChiT,
    required this.fullFare,
    required this.stops,
  });

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitRoute && routeId == other.routeId;

  @override
  int get hashCode => hash(routeId);

  @override
  int compareTo(TransitRoute other) {
    // 1. Compare by route number first
    final numCompare = number.compareTo(other.number);
    if (numCompare != 0) return numCompare;

    // 2. Compare by type (BusRoute before MinibusRoute)
    if (this is BusRoute && other is MinibusRoute) return -1;
    if (this is MinibusRoute && other is BusRoute) return 1;

    // 3. Type-specific comparisons
    if (this is BusRoute && other is BusRoute) {
      final a = this as BusRoute;
      final b = other;

      final companyCompare = Company.compareCompanies(a.companies, b.companies);
      if (companyCompare != 0) return companyCompare;

      final serviceTypeCompare = Utils.nullableCompare(
        a.serviceType,
        b.serviceType,
      );
      if (serviceTypeCompare != 0) return serviceTypeCompare;
    }

    if (this is MinibusRoute && other is MinibusRoute) {
      final a = this as MinibusRoute;
      final b = other;

      final regionCompare = Enum.compareByIndex(a.region, b.region);
      if (regionCompare != 0) return regionCompare;

      // Minibus description compare
      final aNormal = a.isNormal;
      final bNormal = b.isNormal;
      if (aNormal != bNormal) return aNormal ? -1 : 1;
    }

    // 4. Fallback comparisons shared by all
    final boundCompare = Enum.compareByIndex(bound, other.bound);
    if (boundCompare != 0) return boundCompare;

    final originCompare = originEn.compareTo(other.originEn);
    if (originCompare != 0) return originCompare;

    return destEn.compareTo(other.destEn);
  }

  // String getOriginLabel(SupportedLanguage language) => switch (language) {
  //   SupportedLanguage.zh_Hant => originChiT,
  //   SupportedLanguage.zh_Hans => originChiS,
  //   SupportedLanguage.en => originEn,
  // };
  //
  // String getDestinationLabel(SupportedLanguage language) => switch (language) {
  //   SupportedLanguage.zh_Hant => destChiT,
  //   SupportedLanguage.zh_Hans => destChiS,
  //   SupportedLanguage.en => destEn,
  // };
}
