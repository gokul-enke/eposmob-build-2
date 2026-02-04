import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class LiveClock extends StatefulWidget {
  const LiveClock({super.key});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late Timer _timer;
  String _timeString = "";

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _getTime() {
    final String formattedDateTime = _formatTime();
    if (formattedDateTime != _timeString) {
      if (mounted) {
        setState(() {
          _timeString = formattedDateTime;
        });
      }
    }
  }

  String _formatTime() {
    return DateHelper.getCurrentFormattedTimeWithSecondsAMPM();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 16,
            color: ColorManager.kPrimaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            _timeString,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s14,
              0.21,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
