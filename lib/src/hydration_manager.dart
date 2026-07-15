import 'package:flutter/foundation.dart';
import 'package:hilt_core/hilt_core.dart';

import 'data/app_database.dart';
import 'services/hydration_reminder_service.dart';

class HydrationManager extends ChangeNotifier {
  HydrationManager() {
    _init();
  }

  HydrationRepository? _repo;
  HydrationProfile _profile = HydrationProfile();
  HydrationDay _today = HydrationDay();
  List<HydrationEntry> _entries = const [];
  bool _isLoading = true;
  bool _remindersEnabled = false;
  bool _isUpdatingReminders = false;

  bool get isLoading => _isLoading;
  int get dailyGoalMl => _profile.dailyGoalMl;
  int get dailyTotalMl => _today.consumedMl;
  int get remainingMl {
    final remaining = dailyGoalMl - dailyTotalMl;
    return remaining < 0 ? 0 : remaining;
  }
  int get currentStreak => _profile.currentStreak;
  List<HydrationEntry> get entries => _entries;
  HydrationDay get today => _today;
  bool get remindersEnabled => _remindersEnabled;
  bool get isUpdatingReminders => _isUpdatingReminders;

  double get progress {
    if (dailyGoalMl <= 0) return 0;
    final value = dailyTotalMl / dailyGoalMl;
    if (value < 0) return 0;
    if (value > 1.2) return 1.2;
    return value;
  }

  Future<void> _init() async {
    final isar = await AppDatabase.open();
    _repo = HydrationRepository(isar);
    _remindersEnabled = await HydrationReminderService.instance.isEnabled();
    await refreshToday();
  }

  Future<void> refreshToday() async {
    final repo = _repo;
    if (repo == null) return;

    _isLoading = true;
    notifyListeners();

    final snapshot = await repo.loadDay(DateTime.now());
    _applySnapshot(snapshot);
    await _syncReminders();
  }

  Future<int> fetchDailyTotal() async {
    final repo = _repo;
    if (repo == null) return dailyTotalMl;

    final now = DateTime.now();
    final lastLogDate = _profile.lastLogDate;
    if (lastLogDate == null || !_isSameDay(lastLogDate, now)) {
      final snapshot = await repo.loadDay(now);
      _applySnapshot(snapshot);
      return snapshot.day.consumedMl;
    }

    final total = await repo.fetchDailyTotal(now);
    _today.consumedMl = total;
    notifyListeners();
    return total;
  }

  Future<void> addWater(int ml) async {
    if (ml <= 0 || _repo == null) return;
    await _repo!.addWater(ml);
    await refreshToday();
  }

  Future<void> deleteEntry(int id) async {
    if (_repo == null) return;
    await _repo!.deleteEntry(id);
    await refreshToday();
  }

  Future<HydrationReminderEnableResult> toggleSmartReminders(bool enabled) async {
    if (_isUpdatingReminders) {
      return enabled
          ? HydrationReminderEnableResult.unavailable
          : HydrationReminderEnableResult.disabled;
    }

    _isUpdatingReminders = true;
    notifyListeners();

    try {
      final result = await HydrationReminderService.instance.setEnabled(enabled);
      _remindersEnabled = result == HydrationReminderEnableResult.enabled;
      notifyListeners();
      await _syncReminders();
      return result;
    } finally {
      _isUpdatingReminders = false;
      notifyListeners();
    }
  }

  void _applySnapshot(HydrationDaySnapshot snapshot) {
    _profile = snapshot.profile;
    _today = snapshot.day;
    _entries = snapshot.entries;
    _isLoading = false;
    notifyListeners();
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _syncReminders() {
    return HydrationReminderService.instance.syncDailyReminders(
      enabled: _remindersEnabled,
      consumedMl: dailyTotalMl,
      goalMl: dailyGoalMl,
    );
  }
}
