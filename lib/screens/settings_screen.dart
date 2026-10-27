import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/business_info.dart';
import '../services/db_helper.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final biz = await BusinessInfo.load();
    _payableTo.text = biz.payableTo;
    _account.text = biz.accountNumber;
    _bank.text = biz.bank;
    _contactName.text = biz.contactName;
    _contactPhone.text = biz.contactPhone;
    _logoPath = biz.logoPath;
    if (mounted) setState(() => _loading = false);
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
              ],
            ),
    );
  }
}
