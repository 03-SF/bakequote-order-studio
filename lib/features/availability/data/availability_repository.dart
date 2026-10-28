import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/availability.dart';

class SupabaseAvailabilityRepository implements AvailabilityRepository {
  SupabaseAvailabilityRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    void session() {
      if (client.auth.currentUser?.id != userId) {
        throw const AvailabilityFailure('Session changed. Sign in again.');
      }
    }

    session();
    try {
      final result = await client.rpc(name, params: params);
      session();
      return result;
    } on PostgrestException catch (error) {
      throw AvailabilityFailure(switch (error.code) {
        '40001' => 'Another edit was saved. Reload and review before retrying.',
        '23514' =>
          'Existing bookings conflict with this change. No orders were changed.',
        '22023' =>
          'Check the timezone, date, lead days (0–365) and capacity (1–10000).',
        '42501' => 'You do not have access. Sign in again.',
        _ => 'Could not save or load. Check your connection and retry.',
      });
    }
  }

  @override
  Future<AvailabilityCalendar?> calendar(String code, String? start) async {
    final result = await _rpc('bakery_availability', {
      'p_code': code,
      'p_start': start,
      'p_days': start == null
          ? 31
          : DateTime.utc(
              DateTime.parse(start).year,
              DateTime.parse(start).month + 1,
              0,
            ).day,
    });
    if (result == null) return null;
    return AvailabilityCalendar(
      configured: result['configured'],
      timezone: result['timezone'] ?? '',
      today: result['today'] ?? '',
      leadDays: result['lead_days'] ?? 0,
      days: [
        for (final d in result['days'] ?? [])
          AvailabilityDay(d['date'], d['state']),
      ],
    );
  }

  @override
  Future<AvailabilitySettings> settings(String businessId) async {
    final r = await _rpc('owner_availability', {'p_business_id': businessId});
    return AvailabilitySettings(
      r['timezone'] ?? '',
      r['lead_days'] ?? 0,
      r['daily_capacity'] ?? 1,
      r['revision'],
    );
  }

  @override
  Future<void> save(
    String businessId,
    int revision,
    String timezone,
    int leadDays,
    int capacity,
  ) async {
    await _rpc('save_availability', {
      'p_business_id': businessId,
      'p_revision': revision,
      'p_timezone': timezone,
      'p_lead_days': leadDays,
      'p_capacity': capacity,
    });
  }

  @override
  Future<void> block(
    String businessId,
    int revision,
    String date,
    bool blocked,
  ) async {
    await _rpc('set_blocked_date', {
      'p_business_id': businessId,
      'p_revision': revision,
      'p_date': date,
      'p_blocked': blocked,
    });
  }
}
