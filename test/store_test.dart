import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi/main.dart';
import 'package:kudi/models.dart';
import 'package:kudi/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Txn alert(String body, DateTime at) => KudiStore.fromAlert('GTBank', body, at, Source.sms)!;

void main() {
  final day = DateTime(2026, 11, 18, 10);

  test('importing the same alert twice adds it once', () async {
    SharedPreferences.setMockInitialValues({});
    final s = KudiStore();
    await s.load();
    final a = alert('Amt: NGN5,000.00 DR Desc: POS SHOPRITE Avail Bal: NGN45,230.50', day);
    expect(await s.addAll([a]), 1);
    expect(await s.addAll([alert('Amt: NGN5,000.00 DR Desc: POS SHOPRITE Avail Bal: NGN45,230.50', day.add(const Duration(minutes: 1)))]), 0);
    expect(s.txns, hasLength(1));
  });

  test('monthly summary splits spending by category, largest first', () {
    final txns = [
      alert('Amt: NGN5,000.00 DR Desc: POS SHOPRITE Bal: NGN1.00', day),
      alert('Amt: NGN2,000.00 DR Desc: BOLT TRIP Bal: NGN2.00', day),
      alert('Amt: NGN1,500.00 DR Desc: BOLT TRIP Bal: NGN3.00', day),
      alert('Amt: NGN100,000.00 CR Desc: SALARY Bal: NGN4.00', day),
      alert('Amt: NGN9,000.00 DR Desc: POS SHOPRITE Bal: NGN5.00', DateTime(2026, 10, 2)),
    ];
    final s = summarise(txns, day);
    expect(s.spent, 850000);
    expect(s.received, 10000000);
    expect(s.byCategory.first.key, Category.shopping);
    expect(s.byCategory.map((e) => e.key), [Category.shopping, Category.transport]);
  });

  test('budgets and categories persist across restarts', () async {
    SharedPreferences.setMockInitialValues({});
    final a = KudiStore();
    await a.load();
    await a.addAll([alert('Amt: NGN2,000.00 DR Desc: SOMETHING Bal: NGN2.00', day)]);
    await a.recategorise(a.txns.first.id, Category.food);
    await a.setBudget(Category.food, 3000000);
    final b = KudiStore();
    await b.load();
    expect(b.txns.first.category, Category.food);
    expect(b.budgets[Category.food], 3000000);
  });

  testWidgets('onboarding leads to the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = KudiStore();
    await s.load();
    await tester.pumpWidget(KudiApp(store: s));
    await tester.pumpAndSettle();
    expect(find.text('Your bank alerts, sorted'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Where it went'), findsOneWidget);
  });

  testWidgets('pasting an alert previews and saves it', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final s = KudiStore();
    await s.load();
    await tester.pumpWidget(KudiApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Acct:0***123 Amt:NGN5,000.00 DR Desc:CHICKEN REPUBLIC Avail Bal:NGN45,230.50');
    await tester.pumpAndSettle();
    expect(find.text('CHICKEN REPUBLIC'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(s.txns.single.category, Category.food);
    expect(find.text('Food'), findsWidgets);
  });
}
