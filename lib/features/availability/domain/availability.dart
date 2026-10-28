String serviceDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime calendarMonth(DateTime date, int offset) =>
    DateTime.utc(date.year, date.month + offset);

class AvailabilityDay {
  const AvailabilityDay(this.date, this.state);
  final String date, state;
  String get label => state.replaceAll('-', ' ');
}

class AvailabilityCalendar {
  const AvailabilityCalendar({
    required this.configured,
    this.timezone = '',
    this.today = '',
    this.leadDays = 0,
    this.days = const [],
  });
  final bool configured;
  final String timezone, today;
  final int leadDays;
  final List<AvailabilityDay> days;
}

class AvailabilitySettings {
  const AvailabilitySettings(
    this.timezone,
    this.leadDays,
    this.capacity,
    this.revision,
  );
  final String timezone;
  final int leadDays, capacity, revision;
}

class AvailabilityFailure implements Exception {
  const AvailabilityFailure(this.message);
  final String message;
}

abstract interface class AvailabilityRepository {
  Future<AvailabilityCalendar?> calendar(String code, String? start);
  Future<AvailabilitySettings> settings(String businessId);
  Future<void> save(
    String businessId,
    int revision,
    String timezone,
    int leadDays,
    int capacity,
  );
  Future<void> block(
    String businessId,
    int revision,
    String date,
    bool blocked,
  );
}
