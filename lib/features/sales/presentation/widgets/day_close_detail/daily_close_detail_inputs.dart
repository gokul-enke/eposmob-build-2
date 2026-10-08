import 'package:flutter/widgets.dart';

import '../../../domain/models/daily_sales_close.dart';
import '../../state/daily_close_detail_controller.dart';

class DailyCloseDetailInputs {
  const DailyCloseDetailInputs(
      {required this.controller,
      required this.currency,
      required this.onBack,
      required this.onPrint,
      required this.onExport});
  final DailyCloseDetailController controller;
  final String currency;
  final VoidCallback onBack;
  final ValueChanged<DailySalesCloseData> onPrint, onExport;
}
