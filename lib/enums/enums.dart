enum Bound {
  I,
  O;

  String get label => this == I ? 'inbound' : 'outbound';
}

enum Region { HKI, KLN, NT }

enum TransportType { BUS, MINIBUS }
