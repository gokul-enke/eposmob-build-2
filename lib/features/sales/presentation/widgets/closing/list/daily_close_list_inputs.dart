import 'package:flutter/material.dart';

import '../../../../domain/models/daily_sales_close.dart';

class DailyCloseListInputs {
  const DailyCloseListInputs(
      {required this.rows, required this.currency, required this.onView});
  final List<DailySalesCloseData> rows;
  final String currency;
  final ValueChanged<DailySalesCloseData> onView;
}
