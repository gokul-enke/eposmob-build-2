/// The From/To moments a report is filtered by. Either end may be open.
class ReportDateRange {
  const ReportDateRange({this.from, this.to});

  static const empty = ReportDateRange();

  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => from == null && to == null;

  /// From is after To: the report must not be requested.
  bool get isInverted => from != null && to != null && from!.isAfter(to!);

  /// `yyyy-MM-dd HH:mm:ss`, the format the report APIs take.
  String? get apiFrom => from == null ? null : formatApi(from!);
  String? get apiTo => to == null ? null : formatApi(to!);

  ReportDateRange copyWith(
          {DateTime? Function()? from, DateTime? Function()? to}) =>
      ReportDateRange(
        from: from == null ? this.from : from(),
        to: to == null ? this.to : to(),
      );

  static String formatApi(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
        '${two(value.day)} ${two(value.hour)}:${two(value.minute)}:'
        '${two(value.second)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ReportDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}
