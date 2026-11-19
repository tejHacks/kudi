/// Kudi's data: transactions (in kobo, so money maths is exact) and budgets.
enum TxnType { debit, credit }

enum Category {
  food('Food', 0xFFF97316),
  transport('Transport', 0xFF0EA5E9),
  airtime('Airtime & data', 0xFF8B5CF6),
  bills('Bills & power', 0xFFEAB308),
  shopping('Shopping', 0xFFEC4899),
  cash('Cash & POS', 0xFF64748B),
  transfers('Transfers', 0xFF14B8A6),
  fees('Bank charges', 0xFFEF4444),
  income('Income', 0xFF22C55E),
  other('Other', 0xFF94A3B8);

  const Category(this.label, this.color);
  final String label;
  final int color;

  static Category byName(String n) => Category.values.firstWhere((c) => c.name == n, orElse: () => Category.other);
}

enum Source { sms, pasted, manual }

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.kobo,
    required this.at,
    required this.category,
    this.bank = '',
    this.narration = '',
    this.balanceKobo,
    this.source = Source.manual,
  });

  final String id;
  final TxnType type;
  final int kobo;
  final DateTime at;
  final Category category;
  final String bank;
  final String narration;
  final int? balanceKobo;
  final Source source;

  /// Same alert imported twice (or pasted after an SMS import) gets the same key.
  String get dedupeKey =>
      '${type.name}|$kobo|${balanceKobo ?? '-'}|${at.year}-${at.month}-${at.day}|${narration.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

  Txn copyWith({Category? category}) => Txn(
        id: id,
        type: type,
        kobo: kobo,
        at: at,
        category: category ?? this.category,
        bank: bank,
        narration: narration,
        balanceKobo: balanceKobo,
        source: source,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'kobo': kobo,
        'at': at.toIso8601String(),
        'category': category.name,
        'bank': bank,
        'narration': narration,
        'balance': balanceKobo,
        'source': source.name,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: j['type'] == 'credit' ? TxnType.credit : TxnType.debit,
        kobo: j['kobo'] as int,
        at: DateTime.parse(j['at'] as String),
        category: Category.byName(j['category'] as String),
        bank: (j['bank'] ?? '') as String,
        narration: (j['narration'] ?? '') as String,
        balanceKobo: j['balance'] as int?,
        source: Source.values.firstWhere((s) => s.name == j['source'], orElse: () => Source.manual),
      );
}

/// Totals for one calendar month.
class MonthSummary {
  MonthSummary(this.spent, this.received, this.byCategory);
  final int spent;
  final int received;

  /// Spending per category, largest first.
  final List<MapEntry<Category, int>> byCategory;

  int get net => received - spent;
}

MonthSummary summarise(Iterable<Txn> txns, DateTime month) {
  var spent = 0;
  var received = 0;
  final cats = <Category, int>{};
  for (final t in txns) {
    if (t.at.year != month.year || t.at.month != month.month) continue;
    if (t.type == TxnType.credit) {
      received += t.kobo;
    } else {
      spent += t.kobo;
      cats[t.category] = (cats[t.category] ?? 0) + t.kobo;
    }
  }
  final list = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return MonthSummary(spent, received, list);
}
