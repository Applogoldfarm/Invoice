import '../services/db_helper.dart';

class BusinessInfo {
  final String logoPath;
  final String payableTo;
  final String accountNumber;
  final String bank;
  final String contactName;
  final String contactPhone;

  const BusinessInfo({
    this.logoPath = '',
    this.payableTo = '',
    this.accountNumber = '',
    this.bank = '',
    this.contactName = '',
    this.contactPhone = '',
  });

  static Future<BusinessInfo> load() async {
    final db = DbHelper.instance;
    return BusinessInfo(
      logoPath: await db.getSetting('logo_path'),
      payableTo: await db.getSetting('payable_to'),
      accountNumber: await db.getSetting('account_number'),
      bank: await db.getSetting('bank'),
      contactName: await db.getSetting('contact_name'),
      contactPhone: await db.getSetting('contact_phone'),
    );
  }
}
