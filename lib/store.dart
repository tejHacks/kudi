import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'parser.dart';

/// Everything Kudi keeps, on this phone only.
class KudiStore extends ChangeNotifier {
  List<Txn> txns = [];
  Map<Category, int> budgets = {};
  bool onboarded = false;
  bool ready = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('txns');
    if (raw != null) txns = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(Txn.fromJson).toList();
    final b = p.getString('budgets');
    if (b != null) budgets = (jsonDecode(b) as Map<String, dynamic>).map((k, v) => MapEntry(Category.byName(k), v as int));
    onboarded = p.getBool('onboarded') ?? false;
    _sort();
    ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    _sort();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('txns', jsonEncode(txns.map((t) => t.toJson()).toList()));
    await p.setString('budgets', jsonEncode(budgets.map((k, v) => MapEntry(k.name, v))));
  }

  void _sort() => txns.sort((a, b) => b.at.compareTo(a.at));

  Future<void> finishOnboarding() async {
    onboarded = true;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', true);
  }

  /// Add transactions, skipping any already saved. Returns how many were new.
  Future<int> addAll(Iterable<Txn> incoming) async {
    final seen = txns.map((t) => t.dedupeKey).toSet();
    var added = 0;
    for (final t in incoming) {
      if (seen.add(t.dedupeKey)) {
        txns.add(t);
        added++;
      }
    }
    if (added > 0) await _save();
    return added;
  }

  Future<void> recategorise(String id, Category c) async {
    txns = [for (final t in txns) t.id == id ? t.copyWith(category: c) : t];
    await _save();
  }

  Future<void> remove(String id) async {
    txns.removeWhere((t) => t.id == id);
    await _save();
  }

  Future<void> setBudget(Category c, int? kobo) async {
    if (kobo == null || kobo <= 0) {
      budgets.remove(c);
    } else {
      budgets[c] = kobo;
    }
    await _save();
  }

  /// Build a transaction from an alert's text (SMS or pasted).
  static Txn? fromAlert(String sender, String body, DateTime at, Source source) {
    final p = parseAlert(sender, body);
    if (p == null) return null;
    return Txn(
      id: '${at.microsecondsSinceEpoch}-${p.kobo}',
      type: p.type,
      kobo: p.kobo,
      at: at,
      category: categorise(p.type, p.narration),
      bank: p.bank,
      narration: p.narration,
      balanceKobo: p.balanceKobo,
      source: source,
    );
  }
}
