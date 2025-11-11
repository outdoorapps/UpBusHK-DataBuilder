import 'package:json_annotation/json_annotation.dart';

enum Bound {
  @JsonValue('I')
  inbound,
  @JsonValue('O')
  outbound,
}

enum Region { HKI, KLN, NT }

enum TransportType { BUS, MINIBUS }
