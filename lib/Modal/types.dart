/// Small value types that replaced the Firestore `Timestamp` and `GeoPoint`
/// classes, so models and screens kept their shape during the Supabase migration.

class Timestamp implements Comparable<Timestamp> {
  final DateTime _dt;
  Timestamp.fromDate(DateTime date) : _dt = date;
  Timestamp.now() : _dt = DateTime.now();

  /// Parses an ISO-8601 string from Postgres (`timestamptz`).
  factory Timestamp.parse(dynamic v) {
    if (v is Timestamp) return v;
    if (v is DateTime) return Timestamp.fromDate(v);
    if (v is String) return Timestamp.fromDate(DateTime.parse(v).toLocal());
    return Timestamp.now();
  }

  DateTime toDate() => _dt;
  String toIso() => _dt.toUtc().toIso8601String();
  int get millisecondsSinceEpoch => _dt.millisecondsSinceEpoch;

  @override
  int compareTo(Timestamp other) => _dt.compareTo(other._dt);
  @override
  String toString() => 'Timestamp($_dt)';
}

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}
