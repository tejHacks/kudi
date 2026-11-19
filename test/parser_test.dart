import 'package:flutter_test/flutter_test.dart';
import 'package:kudi/models.dart';
import 'package:kudi/parser.dart';

void main() {
  group('bank alert formats', () {
    test('GTBank-style debit with description and balance', () {
      final p = parseAlert('GTBank', 'Acct: 0***123 Amt: NGN5,000.00 DR Desc: POS PURCHASE SHOPRITE IB Avail Bal: NGN45,230.50 Date: 2026-11-18 14:22')!;
      expect(p.type, TxnType.debit);
      expect(p.kobo, 500000);
      expect(p.balanceKobo, 4523050);
      expect(p.bank, 'GTBank');
      expect(p.narration, 'POS PURCHASE SHOPRITE IB');
    });

    test('Access-style "Debit Amt" with airtime', () {
      final p = parseAlert('AccessBank', 'Debit Amt:NGN2,500.00 Acc:123**890 Desc:AIRTIME MTN 0803 Date:18/11/2026 Avail Bal:NGN12,000.00')!;
      expect(p.type, TxnType.debit);
      expect(p.kobo, 250000);
      expect(p.balanceKobo, 1200000);
      expect(categorise(p.type, p.narration), Category.airtime);
    });

    test('Zenith-style credit with amount before NGN', () {
      final p = parseAlert('ZENITHBANK', 'Acct:22**221 DT:18/11/2026 10:21 CR Amt:150,000.00 NGN Desc:SALARY NOV Bal:NGN320,500.00')!;
      expect(p.type, TxnType.credit);
      expect(p.kobo, 15000000);
      expect(p.balanceKobo, 32050000);
      expect(categorise(p.type, p.narration), Category.income);
    });

    test('wallet-style message with ₦ and a counterparty', () {
      final p = parseAlert('OPay', 'You have received ₦7,000.00 from ADE BELLO. Balance: ₦10,250.00')!;
      expect(p.type, TxnType.credit);
      expect(p.kobo, 700000);
      expect(p.balanceKobo, 1025000);
      expect(p.narration, contains('ADE BELLO'));
      expect(p.bank, 'OPay');
    });

    test('"Credit Alert!" is a credit even if "debit" appears later', () {
      final p = parseAlert('', 'Credit Alert! Amt: NGN25,000.00 to your account via debit card reversal. Bal: NGN30,000.00')!;
      expect(p.type, TxnType.credit);
      expect(p.kobo, 2500000);
    });

    test('amounts without decimals and bank charges', () {
      final p = parseAlert('UBA', 'Txn: Debit Acc:2*******56 Amt:NGN50 Des:SMS ALERT CHARGES Date:18-Nov-2026 Bal:NGN9,800.00')!;
      expect(p.kobo, 5000);
      expect(categorise(p.type, p.narration), Category.fees);
    });
  });

  group('ignores non-alerts', () {
    test('an ordinary text', () => expect(parseAlert('Mum', 'Did you eat? Call me when you can'), isNull));
    test('a promo with a price but no debit/credit', () => expect(parseAlert('Promo', 'Get 10GB for N2,000 only! Dial *123#'), isNull));
    test('an OTP', () => expect(parseAlert('GTBank', 'Your OTP is 482913. Do not share it.'), isNull));
  });

  group('categories', () {
    test('common Nigerian spending', () {
      expect(categorise(TxnType.debit, 'BOLT TRIP LAGOS'), Category.transport);
      expect(categorise(TxnType.debit, 'IKEDC PREPAID TOKEN'), Category.bills);
      expect(categorise(TxnType.debit, 'CHICKEN REPUBLIC IKEJA'), Category.food);
      expect(categorise(TxnType.debit, 'ATM WDL GTB YABA'), Category.cash);
      expect(categorise(TxnType.debit, 'NIP TRF TO TOLU ADE'), Category.transfers);
      expect(categorise(TxnType.debit, 'SOMETHING UNKNOWN'), Category.other);
    });
    test('a word inside another word does not match ("data" in "update")', () {
      expect(categorise(TxnType.debit, 'ACCOUNT UPDATE FEE'), isNot(Category.airtime));
    });
  });
}
