import 'package:json_annotation/json_annotation.dart';

enum Company { KMB, LWB, CTB, NLB, MTRB }

enum Bound {
  @JsonValue('I')
  inbound,
  @JsonValue('O')
  outbound,
}

enum Region { HKI, KLN, NT }

enum TransportType { BUS, MINIBUS }
