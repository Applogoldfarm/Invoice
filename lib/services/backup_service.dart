import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';

/// Settings that belong to this phone and must not be copied into or
/// overwritten by a backup file.
const List<String> _deviceOnlySettings = [
  'auto_backup',
  'drive_backup_last',
  'drive_backup_error',
];

class BackupService {
  /// Builds the whole backup (invoices, items, settings, logo) as JSON text.
  static Future<String> buildBackupJson() async {
    final data = await DbHelper.instance.exportAll();
    final settings = Map<String, String>.from(data['settings'] as Map);

    for (final k in _deviceOnlySettings) {
      settings.remove(k);
    }

    // The logo is stored as a file on the phone, so embed it in the backup.
    final logoPath = settings.remove('logo_path') ?? '';

    final out = <String, dynamic>{
      'app': 'invoice_app',
      'version': 1,
      'created': DateTime.now().toIso8601String(),
      'invoices': data['invoices'],
      'items': data['items'],
      'settings': settings,
    };

    if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
      out['logo_base64'] = base64Encode(File(logoPath).readAsBytesSync());
      out['logo_ext'] = p.extension(logoPath);
    }

    return const JsonEncoder.withIndent(' ').convert(out);
  }

  /// Builds a backup file and opens the share sheet
  /// (WhatsApp, Google Drive, email, etc.).
  static Future<void> exportBackup() async {
    final json = await buildBackupJson();

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}';

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'invoice_backup_$stamp.json'));
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Invoice app backup $stamp',
      ),
    );
  }

  /// Lets the user pick a backup file and replaces all current data with it.
  /// Returns the number of invoices restored, or null if the user cancelled.
  static Future<int?> restoreBackup() async {
    final XFile? picked = await openFile();
    if (picked == null) return null;
    return restoreFromJson(await picked.readAsString());
  }

  /// Replaces all current data with the backup text. If the text is not a
  /// valid backup, an exception is thrown and nothing is changed.
  static Future<int> restoreFromJson(String text) async {
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw Exception('This is not a valid backup file.');
    }
    if (data is! Map || data['app'] != 'invoice_app') {
      throw Exception('This is not an invoice app backup file.');
    }

    final settings = <String, String>{
      for (final e in (data['settings'] as Map? ?? {}).entries)
        e.key.toString(): e.value.toString(),
    };

    // Keep this phone's own backup switches as they are.
    for (final k in _deviceOnlySettings) {
      settings.remove(k);
      final current = await DbHelper.instance.getSetting(k);
      if (current.isNotEmpty) settings[k] = current;
    }

    // Put the logo back on the phone and point the settings at it.
    final logoB64 = data['logo_base64'];
    if (logoB64 is String && logoB64.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      final ext = (data['logo_ext'] as String?) ?? '.png';
      final dest = p.join(
        dir.path,
        'logo_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(dest).writeAsBytes(base64Decode(logoB64));
      settings['logo_path'] = dest;
    }

    return DbHelper.instance.importAll(
      (data['invoices'] as List?) ?? [],
      (data['items'] as List?) ?? [],
      settings,
    );
  }
}
