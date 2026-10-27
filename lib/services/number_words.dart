const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen'
];
const _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty',
  'Ninety'
];
const _scales = ['', 'Thousand', 'Million', 'Billion', 'Trillion'];

String _below1000(int n) {
  final parts = <String>[];
  if (n >= 100) {
    parts.add('${_ones[n ~/ 100]} Hundred');
    n %= 100;
    if (n > 0) parts.add('and');
  }
  if (n >= 20) {
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    parts.add(o.isEmpty ? t : '$t-$o');
  } else if (n > 0) {
    parts.add(_ones[n]);
  }
  return parts.join(' ');
}

String _words(int n) {
  if (n == 0) return 'Zero';
  final parts = <String>[];
  var scale = 0;
  while (n > 0) {
    final chunk = n % 1000;
    if (chunk > 0) {
      final w = _below1000(chunk);
      parts.insert(0, _scales[scale].isEmpty ? w : '$w ${_scales[scale]}');
    }
    n ~/= 1000;
    scale++;
  }
  return parts.join(' ');
}

/// 95000 -> "Ninety-five Thousand Naira only"
String amountInWords(double amount) {
  final totalKobo = (amount * 100).round();
  final naira = totalKobo ~/ 100;
  final kobo = totalKobo % 100;
  var text = '${_words(naira)} Naira';
  if (kobo > 0) text += ' and ${_words(kobo)} Kobo';
  return '$text only';
}
