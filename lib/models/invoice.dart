class InvoiceItem {
  int? id;
  int? invoiceId;
  String description;
  double amount;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.description,
    required this.amount,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int?,
        description: m['description'] as String,
        amount: (m['amount'] as num).toDouble(),
      );
}

class Invoice {
  int? id;
  int number;
  DateTime date;
  String clientName;
  String clientAddress;
  String clientPhone;
  double taxRate; // percent, e.g. 7.5
  double otherCosts;
  bool paid;
  List<InvoiceItem> items;

  Invoice({
    this.id,
    required this.number,
    required this.date,
    this.clientName = '',
    this.clientAddress = '',
    this.clientPhone = '',
    this.taxRate = 0,
    this.otherCosts = 0,
    this.paid = false,
    List<InvoiceItem>? items,
  }) : items = items ?? [];

  String get invoiceNumber => 'INV-${number.toString().padLeft(3, '0')}';

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.amount);
  double get taxAmount => subtotal * taxRate / 100;
  double get total => subtotal + taxAmount + otherCosts;

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'date': date.toIso8601String(),
        'client_name': clientName,
        'client_address': clientAddress,
        'client_phone': clientPhone,
        'tax_rate': taxRate,
        'other_costs': otherCosts,
        'paid': paid ? 1 : 0,
      };

  factory Invoice.fromMap(Map<String, dynamic> m, List<InvoiceItem> items) =>
      Invoice(
        id: m['id'] as int?,
        number: m['number'] as int,
        date: DateTime.parse(m['date'] as String),
        clientName: m['client_name'] as String,
        clientAddress: m['client_address'] as String,
        clientPhone: m['client_phone'] as String,
        taxRate: (m['tax_rate'] as num).toDouble(),
        otherCosts: (m['other_costs'] as num).toDouble(),
        paid: ((m['paid'] as num?) ?? 0) == 1,
        items: items,
      );
}
