import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'section_header.dart';

/// A titled, horizontally scrolling shelf (Netflix-style row).
class ShelfRow extends StatelessWidget {
  const ShelfRow({
    super.key,
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.trailing,
  });

  final String title;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, trailing: trailing),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
