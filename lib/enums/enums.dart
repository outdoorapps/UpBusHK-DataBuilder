import 'package:json_annotation/json_annotation.dart';

enum Bound {
  @JsonValue('I')
  inbound,
  @JsonValue('O')
  outbound;

  String get kmbLabel => this == inbound ? 'inbound' : 'outbound';
}

enum Region { HKI, KLN, NT }

enum TransportType { BUS, MINIBUS }
