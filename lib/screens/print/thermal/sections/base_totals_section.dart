import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';

/// Base interface for totals section templates
abstract class TotalsSection {
  List<int> build(
    Generator generator,
    Map<String, DisplayOption>? displayConfig,
    String formattedTotal,
    String? savedTotal,
    String? discountAmount,
    int itemCount,
    DocumentConfig? billDocumentConfig,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    PosFontType fontType,
    PaperSize paperSize,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double taxAmount,
  );
}
