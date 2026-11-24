/// Business details shown in the app (subscription payment instructions and
/// support contacts). Change them here, in one place.
class BusinessConfig {
  BusinessConfig._();

  // Bank account store owners pay their subscription into.
  static const bankName = 'BOC BANK';
  static const bankAccountName = 'M.Z.M SHAHIL';
  static const bankAccountNumber = '93597815';
  static const bankBranch = 'Kolonnawa branch';

  // Support contacts.
  static const supportPhoneDisplay = '+94 76 673 8871';
  static const supportEmail = 'shahil@zingmarketingmastery.com';
  static const supportWhatsAppDisplay = '+94 76 673 8871';

  /// Number dialled from the company drawer.
  /// NOTE: this differs from [supportPhoneDisplay]; confirm which is correct.
  static const companyPhoneDial = '+94766673789';
}
