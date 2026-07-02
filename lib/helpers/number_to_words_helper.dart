class NumberToWordsHelper {
  static const _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(int number) {
    if (number == 0) return 'Zero';
    return _convertHelper(number).trim();
  }

  static String _convertHelper(int number) {
    if (number < 20) {
      return _ones[number];
    } else if (number < 100) {
      return _tens[number ~/ 10] + (number % 10 != 0 ? ' ' + _ones[number % 10] : '');
    } else if (number < 1000) {
      return _ones[number ~/ 100] + ' Hundred' + (number % 100 != 0 ? ' and ' + _convertHelper(number % 100) : '');
    } else if (number < 1000000) {
      return _convertHelper(number ~/ 1000) + ' Thousand' + (number % 1000 != 0 ? ' ' + _convertHelper(number % 1000) : '');
    } else if (number < 1000000000) {
      return _convertHelper(number ~/ 1000000) + ' Million' + (number % 1000000 != 0 ? ' ' + _convertHelper(number % 1000000) : '');
    }
    return '';
  }

  /// Converts a numeric amount to English words with currency labels.
  static String convertAmount(double amount, String currency) {
    final int integerPart = amount.truncate();
    final int decimalPart = ((amount - integerPart) * 100).round();

    String currencyLabel = 'Dollars';
    String decimalLabel = 'Cents';

    final uCurrency = currency.toUpperCase();
    if (uCurrency == 'SAR') {
      currencyLabel = 'Saudi Riyals';
      decimalLabel = 'Halalas';
    } else if (uCurrency == 'AED') {
      currencyLabel = 'UAE Dirhams';
      decimalLabel = 'Fils';
    } else if (uCurrency == 'INR') {
      currencyLabel = 'Rupees';
      decimalLabel = 'Paise';
    } else if (uCurrency == 'USD') {
      currencyLabel = 'Dollars';
      decimalLabel = 'Cents';
    } else {
      currencyLabel = uCurrency;
      decimalLabel = 'Cents';
    }

    String result = '';
    if (integerPart > 0) {
      result += '${convert(integerPart)} $currencyLabel';
    } else {
      result += 'Zero $currencyLabel';
    }

    if (decimalPart > 0) {
      result += ' and ${convert(decimalPart)} $decimalLabel';
    }

    result += ' Only';
    return result;
  }
}
