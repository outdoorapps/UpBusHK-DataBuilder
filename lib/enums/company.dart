// ignore_for_file: constant_identifier_names
enum Company {
  KMB,
  LWB,
  CTB,
  NLB,
  MTRB;

  static int compareCompanies(List<Company> a, List<Company> b) {
    if (a.length != b.length) return a.length.compareTo(b.length);
    for (int i = 0; i < a.length; i++) {
      final diff = Enum.compareByIndex(a[i], b[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
