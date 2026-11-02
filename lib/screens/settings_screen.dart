import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/business_info.dart';
import '../services/backup_service.dart';
import '../services/db_helper.dart';
import '../services/drive_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _payableTo = TextEditingController();
  final _account = TextEditingController();
  final _bank = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String _logoPath = '';
  bool _auto = false;
  String _lastBackup = '';
  String _lastError = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final biz = await BusinessInfo.load();
    final db = DbHelper.instance;
    _payableTo.text = biz.payableTo;
    _account.text = biz.accountNumber;
    _bank.text = biz.bank;
    _contactName.text = biz.contactName;
    _contactPhone.text = biz.contactPhone;
    _logoPath = biz.logoPath;
    _auto = await db.getSetting('auto_backup') == '1';
    _lastBackup = await db.getSetting('drive_backup_last');
    _lastError = await db.getSetting('drive_backup_error');
    if (mounted) setState(() => _loading = false);
  }

  String get _lastBackupText {
    if (_lastBackup.isEmpty) return 'No Google Drive backup yet';
    final t = DateTime.tryParse(_lastBackup);
    if (t == null) return 'No Google Drive backup yet';
    return 'Last Google Drive backup: ${DateFormat('d MMM yyyy, h:mm a').format(t.toLocal())}';
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1000);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(
      dir.path,
      'logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}',
    );
    await File(picked.path).copy(dest);
    setState(() => _logoPath = dest);
  }

  Future<void> _save() async {
    final db = DbHelper.instance;
    await db.setSetting('logo_path', _logoPath);
    await db.setSetting('payable_to', _payableTo.text.trim());
    await db.setSetting('account_number', _account.text.trim());
    await db.setSetting('bank', _bank.text.trim());
    await db.setSetting('contact_name', _contactName.text.trim());
    await db.setSetting('contact_phone', _contactPhone.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
    Navigator.pop(context);
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirmRestore(String buttonLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This will REPLACE all invoices and settings currently on this phone with the ones in the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------- Backup by sharing a file ----------

  Future<void> _backupFile() async {
    setState(() => _busy = true);
    try {
      await BackupService.exportBackup();
    } catch (e) {
      _msg('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFile() async {
    if (!await _confirmRestore('Choose file')) return;
    setState(() => _busy = true);
    try {
      final count = await BackupService.restoreBackup();
      if (count != null) {
        await _load();
        _msg('Restored $count invoice(s)');
      }
    } catch (e) {
      _msg('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Backup to Google Drive ----------

  Future<void> _backupDrive() async {
    setState(() => _busy = true);
    try {
      final email = await DriveBackupService.backupNow();
      await _load();
      _msg('Backed up to Google Drive ($email)');
    } catch (e) {
      _msg('Google Drive backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreDrive() async {
    if (!await _confirmRestore('Restore')) return;
    setState(() => _busy = true);
    try {
      final count = await DriveBackupService.restoreNow();
      if (count == null) {
        _msg('No backup found in Google Drive yet');
      } else {
        await _load();
        _msg('Restored $count invoice(s) from Google Drive');
      }
    } catch (e) {
      _msg('Google Drive restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAuto(bool value) async {
    final db = DbHelper.instance;
    if (!value) {
      await db.setSetting('auto_backup', '0');
      setState(() => _auto = false);
      return;
    }
    // Turning it on does one backup right now, which also makes sure
    // Google sign-in and permission are working.
    setState(() => _busy = true);
    try {
      await DriveBackupService.backupNow();
      await db.setSetting('auto_backup', '1');
      await _load();
      _msg('Automatic backup is on');
    } catch (e) {
      _msg('Could not turn on automatic backup: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _payableTo.dispose();
    _account.dispose();
    _bank.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = _logoPath.isNotEmpty && File(_logoPath).existsSync();
    return Scaffold(
      appBar: AppBar(title: const Text('Business Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Logo',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: hasLogo
                      ? Image.file(File(_logoPath), height: 90)
                      : const Text('No logo selected'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.image),
                      label: const Text('Choose logo'),
                    ),
                    const SizedBox(width: 8),
                    if (hasLogo)
                      TextButton(
                        onPressed: () => setState(() => _logoPath = ''),
                        child: const Text('Remove'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Payment details',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _payableTo,
                  decoration: const InputDecoration(
                    labelText: 'Make all payable to (account name)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _account,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Account number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bank,
                  decoration: const InputDecoration(
                    labelText: 'Bank',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Contact (printed at the bottom)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contactName,
                  decoration: const InputDecoration(
                    labelText: 'Contact name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact phone number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('Save')),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Backup & restore',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Backups include all invoices, settings and your logo. Restoring replaces everything on this phone.',
                ),
                const SizedBox(height: 12),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  const Text('Google Drive',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_lastBackupText,
                      style: TextStyle(color: Colors.grey.shade700)),
                  if (_lastError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _lastError,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _backupDrive,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Back up'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _restoreDrive,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Restore'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Back up automatically'),
                    subtitle: const Text(
                      'Uploads a backup a few seconds after every change, when the phone is online.',
                    ),
                    value: _auto,
                    onChanged: _toggleAuto,
                  ),
                  const SizedBox(height: 8),
                  const Text('Backup file (WhatsApp, email, etc.)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _backupFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Backup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _restoreFile,
                          icon: const Icon(Icons.download),
                          label: const Text('Restore'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
