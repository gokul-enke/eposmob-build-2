import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiveTimeDisplay extends StatefulWidget {
  const LiveTimeDisplay({
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.bold,
  });

  final double fontSize;
  final FontWeight fontWeight;

  @override
  State<LiveTimeDisplay> createState() => _LiveTimeDisplayState();
}

class _LiveTimeDisplayState extends State<LiveTimeDisplay> {
  late Timer _timer;
  late String _timeString;

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    if (mounted) {
      setState(() {
        _timeString = formattedDateTime;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('hh:mm:ss a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeString,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: widget.fontSize,
        fontWeight: widget.fontWeight,
        color: Colors.black87,
      ),
    );
  }
}
