import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/db_helper.dart';
import '../services/format.dart';
import '../services/number_words.dart';

class _ItemRow {
  final TextEditingController desc;
  final TextEditingController amount;

  _ItemRow({String d = '', String a = ''})
      : desc = TextEditingController(text: d),
        amount = TextEditingController(text: a);

  double get value => double.tryParse(amount.text.replaceAll(',', '')) ?? 0;

  void dispose() {
    desc.dispose();
    amount.dispose();
  }
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class InvoiceFormScreen extends StatefulWidget {
  final Invoice? invoice;
  const InvoiceFormScreen({super.key, this.invoice});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _tax = TextEditingController();
  final _other = TextEditingController();
  final List<_ItemRow> _rows = [];
  DateTime _date = DateTime.now();
  int _number = 0;
  bool _paid = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final inv = widget.invoice;
    if (inv != null) {
      _number = inv.number;
      _date = inv.date;
      _paid = inv.paid;
      _name.text = inv.clientName;
      _address.text = inv.clientAddress;
      _phone.text = inv.clientPhone;
      _tax.text = inv.taxRate == 0 ? '' : _plain(inv.taxRate);
      _other.text = inv.otherCosts == 0 ? '' : _plain(inv.otherCosts);
      for (final it in inv.items) {
        _rows.add(_ItemRow(d: it.description, a: _plain(it.amount)));
      }
    } else {
      _number = await DbHelper.instance.nextInvoiceNumber();
    }
    if (_rows.isEmpty) _rows.add(_ItemRow());
    if (mounted) setState(() => _loading = false);
  }

  double get _subtotal => _rows.fold(0.0, (s, r) => s + r.value);
  double get _taxRate => double.tryParse(_tax.text) ?? 0;
  double get _otherCosts => double.tryParse(_other.text) ?? 0;
  double get _taxAmount => _subtotal * _taxRate / 100;
  double get _total => _subtotal + _taxAmount + _otherCosts;

  String get _invoiceNumber => 'INV-${_number.toString().padLeft(3, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final items = _rows
        .where((r) => r.desc.text.trim().isNotEmpty)
        .map((r) => InvoiceItem(
              description: r.desc.text.trim(),
              amount: r.value,
            ))
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }
    final inv = Invoice(
      id: widget.invoice?.id,
      number: _number,
      date: _date,
      clientName: _name.text.trim(),
      clientAddress: _address.text.trim(),
      clientPhone: _phone.text.trim(),
      taxRate: _taxRate,
      otherCosts: _otherCosts,
      paid: _paid,
      items: items,
    );
    await DbHelper.instance.saveInvoice(inv);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _tax.dispose();
    _other.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading
            ? 'Invoice'
            : (widget.invoice == null
                ? 'New $_invoiceNumber'
                : 'Edit $_invoiceNumber')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(formatDate(_date)),
                    subtitle: const Text('Tap to change date'),
                    onTap: _pickDate,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Paid'),
                    subtitle: Text(_paid ? 'This invoice is paid' : 'Not paid yet'),
                    value: _paid,
                    onChanged: (v) => setState(() => _paid = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('Bill To',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter the client name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Items',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _rows.length; i++)
                    Padding(
                      key: ObjectKey(_rows[i]),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _rows[i].desc,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'e.g. 3 Chest Cooler (Big)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _rows[i].amount,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          if (_rows.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => setState(() {
                                _rows.removeAt(i).dispose();
                              }),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _rows.add(_ItemRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tax,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Tax rate (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _other,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Other costs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line('Subtotal', formatMoney(_subtotal)),
                          if (_taxRate > 0)
                            _line('Tax ($_taxRate%)', formatMoney(_taxAmount)),
                          if (_otherCosts > 0)
                            _line('Other costs', formatMoney(_otherCosts)),
                          const Divider(),
                          _line('Total', formatMoney(_total), bold: true),
                          const SizedBox(height: 6),
                          Text(amountInWords(_total),
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save invoice'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
