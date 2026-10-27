import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../domain/ai_models.dart';

/// Chart colours: the app primary first, then distinct supporting hues.
const _palette = [
  AppColors.primary,
  Color(0xFF8EC63D),
  Color(0xFFF59E0B),
  Color(0xFF7C5CDB),
  Color(0xFFE5488F),
  Color(0xFF14B8A6),
  Color(0xFFE5484D),
  Color(0xFF8A9BB8),
];

String formatAiValue(num value, {bool money = false, String? currency}) {
  final text =
      NumberFormat.decimalPatternDigits(decimalDigits: value % 1 == 0 ? 0 : 2)
          .format(value);
  return money && currency != null && currency.isNotEmpty
      ? '$currency $text'
      : text;
}

String _compact(num value) => NumberFormat.compact().format(value);

/// A chart or table the assistant returned with an answer.
class AiVisualView extends StatelessWidget {
  const AiVisualView({super.key, required this.visual});

  final AiVisual visual;

  @override
  Widget build(BuildContext context) {
    final body = switch (visual) {
      AiTable table => _TableView(table: table),
      AiChart chart when chart.type == AiChartType.pie =>
        _PieView(chart: chart),
      AiChart chart when chart.type == AiChartType.line =>
        _SeriesChart(chart: chart, line: true),
      AiChart chart when _isTimeLike(chart.labels) =>
        _SeriesChart(chart: chart, line: false),
      AiChart chart => _RankedBars(chart: chart),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(visual.title,
              style: AppTextStyles.sectionHint
                  .copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          body,
        ],
      ),
    );
  }
}

bool _isTimeLike(List<String> labels) =>
    labels.isNotEmpty &&
    labels.every((l) => RegExp(
            r'^(\d{4}-\d{2}(-\d{2})?|\d{2}:\d{2}|Mon|Tue|Wed|Thu|Fri|Sat|Sun)$')
        .hasMatch(l));

String _shortLabel(String label) {
  final day = DateTime.tryParse(label);
  if (day != null && label.length == 10) return DateFormat.MMMd().format(day);
  if (RegExp(r'^\d{4}-\d{2}$').hasMatch(label))
    return DateFormat.yMMM().format(DateTime.parse('$label-01'));
  return label;
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({required this.chart, required this.line});

  final AiChart chart;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final values = chart.values;
    final peak = values.fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = peak <= 0 ? 1.0 : peak * 1.1;
    final every = (values.length / 6).ceil().clamp(1, 1000);
    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, meta) =>
              Text(_compact(v), style: AppTextStyles.caption),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= chart.labels.length || i % every != 0)
              return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_shortLabel(chart.labels[i]),
                  style: AppTextStyles.caption),
            );
          },
        ),
      ),
    );
    final grid = FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.subtleBorder, strokeWidth: 1));
    return SizedBox(
      height: 170,
      child: line
          ? LineChart(LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: grid,
              titlesData: titles,
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i])
                  ],
                  color: AppColors.primary,
                  barWidth: 2.2,
                  dotData: FlDotData(show: values.length <= 31),
                  belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.12)),
                ),
              ],
            ))
          : BarChart(BarChartData(
              maxY: maxY,
              gridData: grid,
              titlesData: titles,
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: AppColors.primary,
                      width: values.length > 20 ? 6 : 14,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ]),
              ],
            )),
    );
  }
}

/// Long labels (product names) read best as labelled horizontal bars.
class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.chart});

  final AiChart chart;

  @override
  Widget build(BuildContext context) {
    final peak = chart.values.fold<double>(0, (m, v) => v > m ? v : m);
    return Column(
      children: [
        for (var i = 0; i < chart.labels.length && i < chart.values.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(chart.labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: peak <= 0 ? 0 : chart.values[i] / peak,
                      minHeight: 9,
                      color: AppColors.primary,
                      backgroundColor: AppColors.canvas,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                    formatAiValue(chart.values[i],
                        money: chart.isMoney, currency: chart.currency),
                    style: AppTextStyles.caption),
              ],
            ),
          ),
      ],
    );
  }
}

class _PieView extends StatelessWidget {
  const _PieView({required this.chart});

  final AiChart chart;

  @override
  Widget build(BuildContext context) {
    final total = chart.values.fold<double>(0, (s, v) => s + v);
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(PieChartData(
            centerSpaceRadius: 30,
            sectionsSpace: 1,
            sections: [
              for (var i = 0; i < chart.values.length; i++)
                PieChartSectionData(
                    value: chart.values[i],
                    color: _palette[i % _palette.length],
                    radius: 22,
                    showTitle: false),
            ],
          )),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0;
                  i < chart.labels.length && i < chart.values.length;
                  i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: _palette[i % _palette.length],
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                          child: Text(chart.labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body)),
                      Text(
                        '${total <= 0 ? 0 : (chart.values[i] / total * 100).round()}%',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table});

  final AiTable table;

  @override
  Widget build(BuildContext context) {
    String cell(int column, Object value) =>
        table.moneyColumns.contains(column) && value is num
            ? formatAiValue(value, money: true, currency: table.currency)
            : value is num
                ? formatAiValue(value)
                : '$value';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 36,
        horizontalMargin: 4,
        columnSpacing: AppSpacing.xl,
        headingTextStyle: AppTextStyles.tableHeader,
        columns: [
          for (var c = 0; c < table.columns.length; c++)
            DataColumn(
                label: Text(table.columns[c]),
                numeric: table.moneyColumns.contains(c)),
        ],
        rows: [
          for (final row in table.rows)
            DataRow(cells: [
              for (var c = 0; c < table.columns.length; c++)
                DataCell(Text(c < row.length ? cell(c, row[c]) : '',
                    style: AppTextStyles.body)),
            ]),
        ],
      ),
    );
  }
}
