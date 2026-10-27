import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/business_info.dart';
import '../models/invoice.dart';
import '../services/db_helper.dart';
import '../services/format.dart';
import '../services/pdf_service.dart';
import 'invoice_form_screen.dart';
import 'settings_screen.dart';

enum _Filter { all, unpaid, paid }

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final _searchCtrl = TextEditingController();
  List<Invoice> _invoices = [];
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DbHelper.instance.getInvoices();
    if (mounted) {
      setState(() {
        _invoices = list;
        _loading = false;
      });
    }
  }

  List<Invoice> get _filtered {
    final q = _query.trim().toLowerCase();
    return _invoices.where((inv) {
      if (_filter == _Filter.paid && !inv.paid) return false;
      if (_filter == _Filter.unpaid && inv.paid) return false;
      if (q.isEmpty) return true;
      return inv.clientName.toLowerCase().contains(q) ||
          inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.clientPhone.toLowerCase().contains(q) ||
          inv.items.any((i) => i.description.toLowerCase().contains(q));
    }).toList();
  }

  double get _unpaidTotal =>
      _invoices.where((i) => !i.paid).fold(0.0, (s, i) => s + i.total);

  int get _unpaidCount => _invoices.where((i) => !i.paid).length;

  Future<void> _open([Invoice? inv]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceFormScreen(invoice: inv)),
    );
    if (changed == true) _load();
  }

  Future<void> _togglePaid(Invoice inv) async {
    await DbHelper.instance.setPaid(inv.id!, !inv.paid);
    _load();
  }

  Future<void> _share(Invoice inv) async {
    final biz = await BusinessInfo.load();
    final bytes = await PdfService.build(inv, biz);
    await Printing.sharePdf(bytes: bytes, filename: '${inv.invoiceNumber}.pdf');
  }

  Future<void> _print(Invoice inv) async {
    final biz = await BusinessInfo.load();
    final bytes = await PdfService.build(inv, biz);
    await Printing.layoutPdf(
      name: inv.invoiceNumber,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _delete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${inv.invoiceNumber}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await DbHelper.instance.deleteInvoice(inv.id!);
      _load();
    }
  }

  Widget _filterChip(String label, _Filter f) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == f,
        onSelected: (_) => setState(() => _filter = f),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Business settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No invoices yet.\nTap "New invoice" to create one.\n\nTip: open Settings (top right) first to add your logo and payment details.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search name, invoice no, phone, item...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          _filterChip('All', _Filter.all),
                          _filterChip('Unpaid', _Filter.unpaid),
                          _filterChip('Paid', _Filter.paid),
                        ],
                      ),
                    ),
                    if (_unpaidCount > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Outstanding: ${formatMoney(_unpaidTotal)} ($_unpaidCount unpaid)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ),
                    const Divider(height: 8),
                    Expanded(
                      child: shown.isEmpty
                          ? const Center(child: Text('No invoices match.'))
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 90),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final inv = shown[i];
                                return ListTile(
                                  title: Text(
                                      '${inv.invoiceNumber}  -  ${inv.clientName}'),
                                  subtitle: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              '${formatDate(inv.date)}   |   ${formatMoney(inv.total)}   |   ',
                                        ),
                                        TextSpan(
                                          text: inv.paid ? 'PAID' : 'UNPAID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: inv.paid
                                                ? Colors.green.shade700
                                                : Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: () => _open(inv),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'paid':
                                          _togglePaid(inv);
                                          break;
                                        case 'share':
                                          _share(inv);
                                          break;
                                        case 'print':
                                          _print(inv);
                                          break;
                                        case 'edit':
                                          _open(inv);
                                          break;
                                        case 'delete':
                                          _delete(inv);
                                          break;
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'paid',
                                        child: Text(inv.paid
                                            ? 'Mark as unpaid'
                                            : 'Mark as paid'),
                                      ),
                                      const PopupMenuItem(
                                          value: 'share',
                                          child: Text('Share PDF')),
                                      const PopupMenuItem(
                                          value: 'print',
                                          child: Text('Preview / Print')),
                                      const PopupMenuItem(
                                          value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete')),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
