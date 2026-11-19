/// Turns a Nigerian bank alert (SMS or pasted text) into a transaction.
///
/// Banks all word alerts differently, so instead of one template per bank this
/// looks for the parts every alert has: a debit/credit marker, an amount, and
/// usually a balance and a description. Anything without a clear amount and
/// direction is ignored, so ordinary SMS never become transactions.
library;

import 'models.dart';

class ParsedAlert {
  ParsedAlert({required this.type, required this.kobo, required this.bank, required this.narration, this.balanceKobo});
  final TxnType type;
  final int kobo;
  final String bank;
  final String narration;
  final int? balanceKobo;
}

/// Sender IDs and names → display name.
const _banks = <String, String>{
  'gtbank': 'GTBank', 'gtb': 'GTBank', 'guaranty': 'GTBank',
  'accessbank': 'Access Bank', 'access': 'Access Bank',
  'zenithbank': 'Zenith Bank', 'zenith': 'Zenith Bank',
  'uba': 'UBA',
  'firstbank': 'First Bank', 'fbn': 'First Bank',
  'opay': 'OPay',
  'kuda': 'Kuda',
  'moniepoint': 'Moniepoint',
  'palmpay': 'PalmPay',
  'fcmb': 'FCMB',
  'sterling': 'Sterling Bank',
  'wema': 'Wema Bank', 'alat': 'Wema Bank',
  'fidelity': 'Fidelity Bank',
  'union': 'Union Bank',
  'stanbic': 'Stanbic IBTC',
  'ecobank': 'Ecobank',
  'polaris': 'Polaris Bank',
  'keystone': 'Keystone Bank',
};

final _money = RegExp(r'(?:NGN|₦|\bN)\s?(\d[\d,]*(?:\.\d{1,2})?)|(\d[\d,]*\.\d{2})\s?NGN', caseSensitive: false);
final _debitWord = RegExp(r'\b(?:DR|debit(?:ed)?|withdrawal|sent|purchase|paid|transfer to)\b', caseSensitive: false);
final _creditWord = RegExp(r'\b(?:CR|credit(?:ed)?|received|deposit|reversal|transfer from)\b', caseSensitive: false);
final _desc = RegExp(r'\b(?:desc|des|narration|narr|remarks?|details?)\s*[:\-]\s*(.+?)(?=\s+(?:avail(?:able)?|bal(?:ance)?|date|dt|amt|acct?|time)\b|$)', caseSensitive: false);
final _counterparty = RegExp(r'\b(?:from|to)\s+([A-Z][A-Za-z.&\- ]{2,40}?)(?=[.,]|\s+(?:on|via|ref|balance|bal)\b|$)');
final _financial = RegExp(r'\b(?:acct?|account|bal(?:ance)?|alert|amt|txn|transaction)\b', caseSensitive: false);

int _toKobo(String digits) {
  final clean = digits.replaceAll(',', '');
  final parts = clean.split('.');
  final naira = int.parse(parts[0]);
  final kobo = parts.length > 1 ? int.parse(parts[1].padRight(2, '0').substring(0, 2)) : 0;
  return naira * 100 + kobo;
}

String bankName(String sender, String body) {
  final hay = '${sender.toLowerCase()} ${body.toLowerCase()}';
  final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  for (final e in _banks.entries) {
    if (s.contains(e.key)) return e.value;
  }
  for (final e in _banks.entries) {
    if (e.key.length > 3 && hay.contains(e.key)) return e.value;
  }
  return '';
}

ParsedAlert? parseAlert(String sender, String body) {
  final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  final bank = bankName(sender, text);
  if (bank.isEmpty && !_financial.hasMatch(text)) return null;

  // Direction: whichever marker appears first wins ("Credit Alert! ... debit card" is a credit).
  final d = _debitWord.firstMatch(text);
  final c = _creditWord.firstMatch(text);
  if (d == null && c == null) return null;
  final type = c == null || (d != null && d.start < c.start) ? TxnType.debit : TxnType.credit;

  int? amount;
  int? balance;
  for (final m in _money.allMatches(text)) {
    final before = text.substring((m.start - 22).clamp(0, m.start), m.start).toLowerCase();
    final kobo = _toKobo(m.group(1) ?? m.group(2)!);
    if (before.contains('bal')) {
      balance ??= kobo;
    } else {
      amount ??= kobo;
    }
  }
  if (amount == null || amount == 0) return null;

  var narration = _desc.firstMatch(text)?.group(1)?.trim() ?? '';
  if (narration.isEmpty) narration = _counterparty.firstMatch(text)?.group(0)?.trim() ?? '';
  return ParsedAlert(type: type, kobo: amount, bank: bank, narration: narration, balanceKobo: balance);
}

const _rules = <Category, List<String>>{
  Category.fees: ['sms alert', 'sms charge', 'vat', 'stamp duty', 'maint', 'cot', 'card fee', 'charges'],
  Category.airtime: ['airtime', 'data', 'mtn', 'glo', 'airtel', '9mobile', 'recharge'],
  Category.bills: ['dstv', 'gotv', 'startimes', 'phcn', 'nepa', 'ikedc', 'ekedc', 'ibedc', 'aedc', 'eedc', 'phed', 'kedco', 'prepaid', 'electricity', 'water', 'internet', 'spectranet', 'smile'],
  Category.transport: ['uber', 'bolt', 'indrive', 'taxify', 'transport', 'fuel', 'petrol', 'filling station', 'brt', 'cowry'],
  Category.food: ['chicken republic', 'kfc', 'domino', 'mr bigg', 'tantalizers', 'chowdeck', 'glovo', 'restaurant', 'eatery', 'food', 'kitchen', 'suya', 'bukka'],
  Category.shopping: ['shoprite', 'spar', 'jumia', 'konga', 'market', 'store', 'supermarket', 'mall', 'pharmacy'],
  Category.cash: ['atm', 'pos', 'cash'],
  Category.transfers: ['trf', 'transfer', 'nip', 'sent', 'to '],
};

/// Best-guess category from the narration. Credits are always Income.
Category categorise(TxnType type, String narration) {
  if (type == TxnType.credit) return Category.income;
  final n = narration.toLowerCase();
  for (final e in _rules.entries) {
    if (e.value.any((k) => RegExp('\\b${RegExp.escape(k.trim())}\\b').hasMatch(n))) return e.key;
  }
  return Category.other;
}
