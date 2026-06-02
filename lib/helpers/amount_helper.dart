import 'package:intl/intl.dart';

class AmountHelper {
  static String formatAmount(dynamic amount) {
    // Check if the amount is a string and attempt to parse it
    if (amount is String) {
      // Try to parse the string to a double
      double? parsedAmount = double.tryParse(amount);
      if (parsedAmount != null) {
        amount = parsedAmount; // Update amount to the parsed double
      } else {
        return 'Invalid amount'; // Handle invalid string input
      }
    } else if (amount is! num) {
      return 'Invalid amount'; // Handle case where amount is not a number
    }

    // Now amount is guaranteed to be a num (int or double)
    final NumberFormat formatter = NumberFormat('#,##0.00');
    return formatter.format(amount);
  }

  // Add this utility function to convert numbers to words
  String convertNumberToWords(double number, {String currency = 'INR', String language = 'en'}) {
    // Route to language-specific implementations
    if (language.toLowerCase() == 'ar') {
      return _convertNumberToWordsArabic(number, currency: currency);
    } else {
      return _convertNumberToWordsEnglish(number, currency: currency);
    }
  }

  // English implementation
  String _convertNumberToWordsEnglish(double number, {String currency = 'INR'}) {
    // Handle 0 case
    if (number == 0) {
      String mainUnit = _getEnglishCurrencyMain(currency, 0);
      return 'Zero $mainUnit';
    }

    // Lists for words
    List<String> ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    List<String> tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    // Separate the whole and decimal parts
    int wholeNumber = number.toInt();
    int decimalPart = ((number - wholeNumber) * 100).round();

    // Guard against values like x.xxx that round cents to 100.
    if (decimalPart == 100) {
      wholeNumber += 1;
      decimalPart = 0;
    }

    String result = '';
    bool isIndianSystem = currency.toUpperCase() == 'INR';

    // Convert the whole part of number
    if (wholeNumber > 0) {
      if (isIndianSystem) {
        result = _convertEnglishIndian(wholeNumber, ones, tens);
      } else {
        result = _convertEnglishInternational(wholeNumber, ones, tens);
      }
    }

    // Get currency units
    String mainUnit = _getEnglishCurrencyMain(currency, wholeNumber);
    String fractionalUnit = _getEnglishCurrencyFractional(currency, decimalPart);

    // Append main currency
    if (wholeNumber > 0) {
      result += ' $mainUnit';
    }

    // Handle decimal part if any
    if (decimalPart > 0) {
      String decimalWords = '';
      if (decimalPart < 20) {
        decimalWords = ones[decimalPart];
      } else {
        decimalWords = tens[decimalPart ~/ 10];
        if (decimalPart % 10 > 0) {
          decimalWords += ' ${ones[decimalPart % 10]}';
        }
      }
      result += ' and $decimalWords $fractionalUnit';
    }

    return result.trim();
  }

  // Helper: English Indian numbering system (Lakhs, Crores)
  String _convertEnglishIndian(int number, List<String> ones, List<String> tens, {bool recursive = false}) {
    String result = '';

    // Crores (10 Million)
    if (number >= 10000000) {
      result += '${_convertEnglishIndian(number ~/ 10000000, ones, tens, recursive: true)} Crore ';
      number %= 10000000;
    }

    // Lakhs (100 Thousand)
    if (number >= 100000) {
      result += '${_convertEnglishIndian(number ~/ 100000, ones, tens, recursive: true)} Lakh ';
      number %= 100000;
    }

    // Thousands
    if (number >= 1000) {
      result += '${_convertEnglishIndian(number ~/ 1000, ones, tens, recursive: true)} Thousand ';
      number %= 1000;
    }

    // Hundreds
    if (number >= 100) {
      result += '${ones[number ~/ 100]} Hundred ';
      number %= 100;
    }

    // Tens and Ones
    if (number > 0) {
      if (number < 20) {
        result += ones[number];
      } else {
        result += '${tens[number ~/ 10]} ';
        if (number % 10 > 0) {
          result += ones[number % 10];
        }
      }
    }

    return result.trim();
  }

  // Helper: English International numbering system (Millions, Billions)
  String _convertEnglishInternational(int number, List<String> ones, List<String> tens, {bool recursive = false}) {
    String result = '';

    // Billions
    if (number >= 1000000000) {
      result += '${_convertEnglishInternational(number ~/ 1000000000, ones, tens, recursive: true)} Billion ';
      number %= 1000000000;
    }

    // Millions
    if (number >= 1000000) {
      result += '${_convertEnglishInternational(number ~/ 1000000, ones, tens, recursive: true)} Million ';
      number %= 1000000;
    }

    // Thousands
    if (number >= 1000) {
      result += '${_convertEnglishInternational(number ~/ 1000, ones, tens, recursive: true)} Thousand ';
      number %= 1000;
    }

    // Hundreds
    if (number >= 100) {
      result += '${ones[number ~/ 100]} Hundred ';
      number %= 100;
    }

    // Tens and Ones
    if (number > 0) {
      if (number < 20) {
        result += ones[number];
      } else {
        result += '${tens[number ~/ 10]} ';
        if (number % 10 > 0) {
          result += ones[number % 10];
        }
      }
    }

    return result.trim();
  }

  // Helper: Get English currency main unit name
  String _getEnglishCurrencyMain(String currency, int value) {
    String upperCurrency = currency.toUpperCase();
    bool isSingular = value == 1;

    switch (upperCurrency) {
      case 'INR':
        return isSingular ? 'Rupee' : 'Rupees';
      case 'SAR':
        return isSingular ? 'Riyal' : 'Riyals';
      default:
        return isSingular ? 'Unit' : 'Units';
    }
  }

  // Helper: Get English currency fractional unit name
  String _getEnglishCurrencyFractional(String currency, int value) {
    String upperCurrency = currency.toUpperCase();
    bool isSingular = value == 1;

    switch (upperCurrency) {
      case 'INR':
        return isSingular ? 'Paise' : 'Paise';
      case 'SAR':
        return isSingular ? 'Halala' : 'Halalas';
      default:
        return isSingular ? 'Decimal' : 'Decimals';
    }
  }

  // Arabic implementation
  String _convertNumberToWordsArabic(double number, {String currency = 'INR'}) {
    // Handle 0 case
    if (number == 0) {
      return 'صفر ${_getArabicCurrencyMain(currency, 0)}';
    }

    // Separate the whole and decimal parts
    int wholeNumber = number.toInt();
    int decimalPart = ((number - wholeNumber) * 100).round();

    String result = '';
    bool isIndianSystem = currency.toUpperCase() == 'INR';

    // Convert the whole part of number
    if (wholeNumber > 0) {
      if (isIndianSystem) {
        result = _convertArabicIndian(wholeNumber);
      } else {
        result = _convertArabicInternational(wholeNumber);
      }
    }

    // Get currency units
    String mainUnit = _getArabicCurrencyMain(currency, wholeNumber);
    String fractionalUnit = _getArabicCurrencyFractional(currency, decimalPart);

    // Append main currency
    if (wholeNumber > 0) {
      result += ' $mainUnit';
    }

    // Handle decimal part if any
    if (decimalPart > 0) {
      String decimalWords = _convertArabicDecimal(decimalPart);
      result += ' و $decimalWords $fractionalUnit';
    }

    return result.trim();
  }

  // Helper: Arabic number words (1-99)
  String _convertArabicTwoDigits(int number) {
    List<String> arabicOnes = [
      '',
      'واحد',
      'اثنان',
      'ثلاثة',
      'أربعة',
      'خمسة',
      'ستة',
      'سبعة',
      'ثمانية',
      'تسعة',
      'عشرة',
      'أحد عشر',
      'اثنا عشر',
      'ثلاثة عشر',
      'أربعة عشر',
      'خمسة عشر',
      'ستة عشر',
      'سبعة عشر',
      'ثمانية عشر',
      'تسعة عشر'
    ];

    List<String> arabicTens = [
      '',
      '',
      'عشرون',
      'ثلاثون',
      'أربعون',
      'خمسون',
      'ستون',
      'سبعون',
      'ثمانون',
      'تسعون'
    ];

    if (number < 20) {
      return arabicOnes[number];
    } else {
      int tens = number ~/ 10;
      int ones = number % 10;
      if (tens < 0 || tens >= arabicTens.length) {
        return arabicOnes[number.clamp(0, arabicOnes.length - 1)];
      }
      if (ones == 0) {
        return arabicTens[tens];
      } else if (ones == 1 || ones == 2) {
        // Special case: one and two come before
        return '${arabicOnes[ones]} و ${arabicTens[tens]}';
      } else {
        return '${arabicOnes[ones]} ${arabicTens[tens]}';
      }
    }
  }

  // Helper: Arabic hundreds (100-999)
  String _convertArabicHundreds(int number) {
    if (number < 100) {
      return _convertArabicTwoDigits(number);
    }

    List<String> arabicHundreds = [
      '',
      'مائة',
      'مائتان',
      'ثلاثمائة',
      'أربعمائة',
      'خمسمائة',
      'ستمائة',
      'سبعمائة',
      'ثمانمائة',
      'تسعمائة'
    ];

    int hundreds = number ~/ 100;
    int remainder = number % 100;

    if (remainder == 0) {
      return arabicHundreds[hundreds];
    } else if (hundreds == 1 || hundreds == 2) {
      return '${arabicHundreds[hundreds]} و ${_convertArabicTwoDigits(remainder)}';
    } else {
      return '${arabicHundreds[hundreds]} و ${_convertArabicTwoDigits(remainder)}';
    }
  }

  // Helper: Arabic Indian numbering system (Lakhs, Crores)
  String _convertArabicIndian(int number) {
    String result = '';

    // Crores (10 Million) - كرور
    if (number >= 10000000) {
      result += '${_convertArabicHundreds(number ~/ 10000000)} كرور ';
      number %= 10000000;
    }

    // Lakhs (100 Thousand) - لاك
    if (number >= 100000) {
      result += '${_convertArabicHundreds(number ~/ 100000)} لاك ';
      number %= 100000;
    }

    // Thousands - ألف
    if (number >= 1000) {
      int thousands = number ~/ 1000;
      number %= 1000;
      if (thousands == 1) {
        result += 'ألف ';
      } else if (thousands == 2) {
        result += 'ألفان ';
      } else if (thousands > 2 && thousands < 11) {
        result += '${_convertArabicTwoDigits(thousands)} آلاف ';
      } else {
        result += '${_convertArabicHundreds(thousands)} ألف ';
      }
    }

    // Hundreds and below
    if (number > 0) {
      result += '${_convertArabicHundreds(number)} ';
    }

    return result.trim();
  }

  // Helper: Arabic International numbering system (Millions, Billions)
  String _convertArabicInternational(int number) {
    String result = '';

    // Billions - مليار
    if (number >= 1000000000) {
      int billions = number ~/ 1000000000;
      number %= 1000000000;
      if (billions == 1) {
        result += 'مليار ';
      } else if (billions == 2) {
        result += 'ملياران ';
      } else if (billions > 2 && billions < 11) {
        result += '${_convertArabicTwoDigits(billions)} مليارات ';
      } else {
        result += '${_convertArabicHundreds(billions)} مليار ';
      }
    }

    // Millions - مليون
    if (number >= 1000000) {
      int millions = number ~/ 1000000;
      number %= 1000000;
      if (millions == 1) {
        result += 'مليون ';
      } else if (millions == 2) {
        result += 'مليونان ';
      } else if (millions > 2 && millions < 11) {
        result += '${_convertArabicTwoDigits(millions)} ملايين ';
      } else {
        result += '${_convertArabicHundreds(millions)} مليون ';
      }
    }

    // Thousands - ألف
    if (number >= 1000) {
      int thousands = number ~/ 1000;
      number %= 1000;
      if (thousands == 1) {
        result += 'ألف ';
      } else if (thousands == 2) {
        result += 'ألفان ';
      } else if (thousands > 2 && thousands < 11) {
        result += '${_convertArabicTwoDigits(thousands)} آلاف ';
      } else {
        result += '${_convertArabicHundreds(thousands)} ألف ';
      }
    }

    // Hundreds and below
    if (number > 0) {
      result += '${_convertArabicHundreds(number)} ';
    }

    return result.trim();
  }

  // Helper: Convert decimal part to Arabic words
  String _convertArabicDecimal(int number) {
    if (number < 100) {
      return _convertArabicTwoDigits(number);
    }
    return _convertArabicHundreds(number);
  }

  // Helper: Get Arabic currency main unit name
  String _getArabicCurrencyMain(String currency, int value) {
    String upperCurrency = currency.toUpperCase();

    switch (upperCurrency) {
      case 'INR':
        if (value == 0) return 'روبية';
        if (value == 1) return 'روبية';
        if (value == 2) return 'روبيتان';
        if (value > 2 && value < 11) return 'روبيات';
        return 'روبية';
      case 'SAR':
        if (value == 0) return 'ريال';
        if (value == 1) return 'ريال';
        if (value == 2) return 'ريالان';
        if (value > 2 && value < 11) return 'ريالات';
        return 'ريال';
      default:
        return 'وحدة';
    }
  }

  // Helper: Get Arabic currency fractional unit name
  String _getArabicCurrencyFractional(String currency, int value) {
    String upperCurrency = currency.toUpperCase();

    switch (upperCurrency) {
      case 'INR':
        if (value == 1) return 'بيسة';
        if (value == 2) return 'بيستان';
        if (value > 2 && value < 11) return 'بيسات';
        return 'بيسة';
      case 'SAR':
        if (value == 1) return 'هللة';
        if (value == 2) return 'هللتان';
        if (value > 2 && value < 11) return 'هللات';
        return 'هللة';
      default:
        return 'عشري';
    }
  }

  /// Rounds amount to nearest integer using standard rounding rules
  /// Example: 2.4 -> 2, 2.5 -> 3, 2.6 -> 3
  static double roundOffAmount(double amount) {
    return amount.roundToDouble();
  }

  /// Formats rounded amount
  static String formatRoundedAmount(double amount) {
    double rounded = roundOffAmount(amount);
    return rounded.toStringAsFixed(0); // No decimal places for rounded amounts
  }
}
