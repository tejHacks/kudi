import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'sms_import.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KudiApp(store: KudiStore()..load()));
}

const _brand = Color(0xFF1E3A8A);
const _gold = Color(0xFFF59E0B);
final _naira = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
String money(int kobo) => _naira.format(kobo / 100);

class KudiApp extends StatelessWidget {
  const KudiApp({super.key, required this.store});
  final KudiStore store;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) {
      final scheme = ColorScheme.fromSeed(seedColor: _brand, brightness: b);
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF7F8FB) : null,
        cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), color: scheme.surfaceContainerLowest),
      );
    }

    return MaterialApp(
      title: 'Kudi',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.ready) return const Scaffold();
          return store.onboarded ? Shell(store: store) : Onboarding(onDone: store.finishOnboarding);
        },
      ),
    );
  }
}

/* ------------------------------------------------------------ onboarding */

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _pages = PageController();
  int _page = 0;

  static const _slides = [
    (Icons.sms_outlined, 'Your bank alerts, sorted', 'Kudi reads the debit and credit alerts you already get and turns them into a clear picture of your money.'),
    (Icons.pie_chart_outline, 'See where it goes', 'Food, transport, airtime, bills, POS: every naira gets a category, and you can fix any guess with a tap.'),
    (Icons.lock_outline, 'Private by design', 'No bank login, no account, no server. Everything stays on this phone.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: widget.onDone, child: const Text('Skip'))),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final (icon, title, body) = _slides[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(28)),
                          child: Icon(icon, size: 48, color: _gold),
                        ),
                        const SizedBox(height: 36),
                        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 12),
                        Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.onSurfaceVariant, height: 1.5)),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: i == _page ? _brand : c.outlineVariant, borderRadius: BorderRadius.circular(4)),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _brand, minimumSize: const Size(140, 54)),
                    onPressed: last ? widget.onDone : () => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: Text(last ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ shell */

class Shell extends StatefulWidget {
  const Shell({super.key, required this.store});
  final KudiStore store;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [HomeScreen(store: widget.store), ActivityScreen(store: widget.store), BudgetsScreen(store: widget.store)];
    return Scaffold(
      body: pages[_tab],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: () => showAddSheet(context, widget.store),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Budgets'),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ home */

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});
  final KudiStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final s = summarise(store.txns, now);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('Kudi', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spent in ${DateFormat('MMMM').format(now)}', style: text.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(money(s.spent), style: text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Pill(icon: Icons.south_west, label: 'In', value: money(s.received)),
                    const SizedBox(width: 10),
                    _Pill(icon: Icons.balance, label: 'Net', value: money(s.net)),
                  ],
                ),
              ],
            ),
          ),
          if (canReadSms) ...[const SizedBox(height: 14), _ImportCard(store: store)],
          const SizedBox(height: 24),
          Text('Where it went', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (s.byCategory.isEmpty)
            const _Empty(text: 'No spending yet this month. Import your alerts or tap Add.')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [for (final e in s.byCategory) _CategoryBar(category: e.key, kobo: e.value, total: s.spent, budget: store.budgets[e.key])]),
              ),
            ),
          const SizedBox(height: 24),
          Text('Recent', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (store.txns.isEmpty)
            const _Empty(text: 'Your transactions will show up here.')
          else
            Card(child: Column(children: [for (final t in store.txns.take(5)) TxnTile(txn: t, store: store)])),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, size: 16, color: _gold),
            const SizedBox(width: 6),
            Text('$label ', style: const TextStyle(color: Colors.white70)),
            Expanded(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ),
      );
}

class _ImportCard extends StatefulWidget {
  const _ImportCard({required this.store});
  final KudiStore store;
  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  bool _busy = false;
  String? _msg;

  Future<void> _run() async {
    setState(() => _busy = true);
    final r = await importSms(widget.store);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = r.denied ? 'Kudi needs SMS permission to read alerts. You can paste alerts instead.' : 'Checked ${r.scanned} messages: ${r.found} bank alerts, ${r.added} new.';
    });
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: const CircleAvatar(backgroundColor: Color(0x221E3A8A), child: Icon(Icons.sms_outlined, color: _brand)),
          title: const Text('Import bank alerts', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_msg ?? 'Reads alerts from your SMS inbox, on this phone only.'),
          trailing: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.chevron_right),
          onTap: _busy ? null : _run,
        ),
      );
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.kobo, required this.total, this.budget});
  final Category category;
  final int kobo;
  final int total;
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    final over = budget != null && kobo > budget!;
    final fraction = budget != null ? (kobo / budget!).clamp(0.0, 1.0) : (total == 0 ? 0.0 : kobo / total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(children: [
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 10),
            Expanded(child: Text(category.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(money(kobo), style: TextStyle(fontWeight: FontWeight.w700, color: over ? Colors.red : null)),
            if (budget != null) Text(' / ${money(budget!)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fraction, minHeight: 7, color: over ? Colors.red : color, backgroundColor: color.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

/* ------------------------------------------------------------ activity */

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, required this.store});
  final Txn txn;
  final KudiStore store;

  @override
  Widget build(BuildContext context) {
    final credit = txn.type == TxnType.credit;
    final color = Color(txn.category.color);
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(credit ? Icons.south_west : Icons.north_east, color: color, size: 20)),
      title: Text(txn.narration.isEmpty ? txn.category.label : txn.narration, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${txn.category.label} · ${DateFormat('d MMM').format(txn.at)}${txn.bank.isEmpty ? '' : ' · ${txn.bank}'}'),
      trailing: Text('${credit ? '+' : '−'}${money(txn.kobo)}', style: TextStyle(fontWeight: FontWeight.w800, color: credit ? const Color(0xFF16A34A) : null)),
      onTap: () => _pickCategory(context),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Category', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final c in Category.values)
              ListTile(
                leading: CircleAvatar(radius: 6, backgroundColor: Color(c.color)),
                title: Text(c.label),
                trailing: c == txn.category ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await store.recategorise(txn.id, picked);
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.store});
  final KudiStore store;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Category? _filter;

  @override
  Widget build(BuildContext context) {
    final list = widget.store.txns.where((t) => _filter == null || t.category == _filter).toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text('Activity', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null))),
                for (final c in Category.values)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(c.label), selected: _filter == c, onSelected: (_) => setState(() => _filter = c))),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Nothing here yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: list.length,
                    itemBuilder: (_, i) => Dismissible(
                      key: ValueKey(list[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.delete, color: Colors.white)),
                      onDismissed: (_) => widget.store.remove(list[i].id),
                      child: TxnTile(txn: list[i], store: widget.store),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ budgets */

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key, required this.store});
  final KudiStore store;

  @override
  Widget build(BuildContext context) {
    final s = summarise(store.txns, DateTime.now());
    final spentBy = {for (final e in s.byCategory) e.key: e.value};
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('Budgets', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Set a monthly limit for any category. Tap to change it.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final c in Category.values.where((c) => c != Category.income))
                  ListTile(
                    leading: CircleAvatar(radius: 6, backgroundColor: Color(c.color)),
                    title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(store.budgets[c] == null ? 'No limit · ${money(spentBy[c] ?? 0)} spent' : '${money(spentBy[c] ?? 0)} of ${money(store.budgets[c]!)}'),
                    trailing: store.budgets[c] != null && (spentBy[c] ?? 0) > store.budgets[c]!
                        ? const Icon(Icons.warning_amber, color: Colors.red)
                        : const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _edit(context, c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, Category c) async {
    final ctrl = TextEditingController(text: store.budgets[c] == null ? '' : (store.budgets[c]! ~/ 100).toString());
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.label} budget'),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₦ ', hintText: 'Monthly limit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Remove')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    final naira = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
    await store.setBudget(c, naira == null ? null : naira * 100);
  }
}

/* ------------------------------------------------------------ add */

Future<void> showAddSheet(BuildContext context, KudiStore store) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), child: AddSheet(store: store)),
    );

class AddSheet extends StatefulWidget {
  const AddSheet({super.key, required this.store});
  final KudiStore store;
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  bool _paste = true;
  final _alert = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TxnType _type = TxnType.debit;
  Category _cat = Category.food;

  Txn? get _parsed => _alert.text.trim().isEmpty ? null : KudiStore.fromAlert('', _alert.text, DateTime.now(), Source.pasted);

  Future<void> _save() async {
    Txn? t;
    if (_paste) {
      t = _parsed;
    } else {
      final naira = double.tryParse(_amount.text.replaceAll(',', ''));
      if (naira != null && naira > 0) {
        t = Txn(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          type: _type,
          kobo: (naira * 100).round(),
          at: DateTime.now(),
          category: _type == TxnType.credit ? Category.income : _cat,
          narration: _note.text.trim(),
        );
      }
    }
    if (t == null) return;
    await widget.store.addAll([t]);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _parsed;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Paste an alert'), icon: Icon(Icons.content_paste)),
                ButtonSegment(value: false, label: Text('Enter it'), icon: Icon(Icons.edit)),
              ],
              selected: {_paste},
              onSelectionChanged: (s) => setState(() => _paste = s.first),
            ),
            const SizedBox(height: 16),
            if (_paste) ...[
              TextField(
                controller: _alert,
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste a bank alert, e.g.\nAcct:0***123 Amt:NGN5,000.00 DR Desc:POS SHOPRITE Avail Bal:NGN45,230.50'),
              ),
              const SizedBox(height: 12),
              if (_alert.text.trim().isNotEmpty)
                p == null
                    ? const Text("Couldn't find an amount and debit/credit in that text.", style: TextStyle(color: Colors.red))
                    : TxnTile(txn: p, store: widget.store),
            ] else ...[
              SegmentedButton<TxnType>(
                segments: const [ButtonSegment(value: TxnType.debit, label: Text('Spent')), ButtonSegment(value: TxnType.credit, label: Text('Received'))],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Amount', prefixText: '₦ ')),
              const SizedBox(height: 12),
              TextField(controller: _note, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'What was it for? (optional)')),
              if (_type == TxnType.debit) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in Category.values.where((c) => c != Category.income)) ChoiceChip(label: Text(c.label), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                ]),
              ],
            ],
            const SizedBox(height: 16),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: _brand, minimumSize: const Size.fromHeight(54)), onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
