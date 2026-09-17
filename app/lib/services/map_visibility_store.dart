// app/lib/services/map_visibility_store.dart
// bray (Bo's drive notes 2026-09-16 #1): which family members are hidden on
// the MAP on this device. A hidden person keeps sharing, keeps their account,
// still counts in "N home · M out" and still has a card - only their marker,
// capsule, edge chip and trail stay off the map. Kept in SharedPreferences
// (like contact_link_store.dart); nothing here talks to the server.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';

class MapVisibilityStore extends ChangeNotifier {
  MapVisibilityStore();

  static MapVisibilityStore instance = MapVisibilityStore();

  static const String key = 'map_hidden_members';

  final Set<String> _hidden = <String>{};
  Future<void>? _loading;

  Set<String> get hiddenIds => Set<String>.unmodifiable(_hidden);
  bool isHidden(String memberId) => _hidden.contains(memberId);

  /// Reads the saved set. Safe to call many times.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _hidden
        ..clear()
        ..addAll(prefs.getStringList(key) ?? const <String>[]);
    } catch (e) {
      debugPrint('MapVisibilityStore: load failed: $e');
    }
    notifyListeners();
  }

  /// Show or hide one person on the map; saved at once.
  Future<void> setHidden(String memberId, bool hidden) async {
    final bool changed = hidden ? _hidden.add(memberId) : _hidden.remove(memberId);
    if (!changed) return;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, _hidden.toList()..sort());
    } catch (e) {
      debugPrint('MapVisibilityStore: save failed: $e');
    }
  }

  /// The members that go on the map: everyone not hidden here.
  List<Member> shown(List<Member> members) =>
      _hidden.isEmpty ? members : members.where((Member m) => !_hidden.contains(m.id)).toList();
}
