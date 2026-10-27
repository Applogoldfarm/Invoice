import 'package:intl/intl.dart';

String ordinal(int d) {
  if (d >= 11 && d <= 13) return '${d}th';
  switch (d % 10) {
    case 1:
      return '${d}st';
    case 2:
      return '${d}nd';
    case 3:
      return '${d}rd';
    default:
      return '${d}th';
  }
}

/// 2026-10-23 -> "23rd October 2026"
String formatDate(DateTime d) =>
    '${ordinal(d.day)} ${DateFormat('MMMM yyyy').format(d)}';

/// 45000 -> "45,000"   1250.5 -> "1,250.50"
String formatMoney(double v) {
  final whole = v == v.roundToDouble();
  return NumberFormat(whole ? '#,##0' : '#,##0.00').format(v);
}
