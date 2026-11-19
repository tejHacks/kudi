import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models.dart';
import 'store.dart';

/// Only Android lets apps read SMS. iOS users paste alerts instead.
bool get canReadSms => !kIsWeb && Platform.isAndroid;

class SmsImportResult {
  SmsImportResult({required this.scanned, required this.found, required this.added, this.denied = false});
  final int scanned;
  final int found;
  final int added;
  final bool denied;
}

/// Read the inbox (on the phone, nothing is uploaded) and add every bank alert.
Future<SmsImportResult> importSms(KudiStore store, {int limit = 2000}) async {
  final status = await Permission.sms.request();
  if (!status.isGranted) return SmsImportResult(scanned: 0, found: 0, added: 0, denied: true);
  final messages = await SmsQuery().querySms(kinds: [SmsQueryKind.inbox], count: limit);
  final txns = <Txn>[];
  for (final m in messages) {
    final t = KudiStore.fromAlert(m.address ?? '', m.body ?? '', m.date ?? DateTime.now(), Source.sms);
    if (t != null) txns.add(t);
  }
  final added = await store.addAll(txns);
  return SmsImportResult(scanned: messages.length, found: txns.length, added: added);
}
