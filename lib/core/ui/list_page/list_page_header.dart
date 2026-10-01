import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../resources/color_manager.dart';
import '../app_colors.dart';
import 'list_page_scaffold.dart';

class ListPageHeader extends StatelessWidget {
  const ListPageHeader(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.onRefresh,
      this.onAdd,
      this.addLabel,
      this.addShortLabel,
      this.extraActions = const []});
  final IconData icon;
  final String title;
  final String? subtitle, addLabel, addShortLabel;
  final VoidCallback? onRefresh, onAdd;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final compact = size.maxWidth < ListLayoutBreakpoints.header;
        final heading = Row(children: [
          Container(
              width: compact ? 40 : 46,
              height: compact ? 40 : 46,
              decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: ColorManager.kPrimaryColor, size: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.heading,
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w700)),
                if (!compact && subtitle != null)
                  Text(subtitle!,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 13))
              ])),
        ]);
        final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...extraActions,
              if (onRefresh != null)
                IconButton.outlined(
                    onPressed: onRefresh,
                    tooltip: 'list.refresh'.tr,
                    icon: const Icon(Icons.refresh_rounded),
                    style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.control)))),
              if (onAdd != null)
                FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(compact
                        ? (addShortLabel ?? addLabel ?? '')
                        : (addLabel ?? '')),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: ColorManager.kPrimaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.control)))),
            ]);
        if (size.maxWidth < ListLayoutBreakpoints.actions) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), actions]);
        }
        return Row(children: [
          Expanded(child: heading),
          const SizedBox(width: 12),
          actions
        ]);
      });
}
