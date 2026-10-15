// Deprecated in favor of package:material_ui, which needs a newer Flutter than
// CI's oldest one. Migrating is tracked in #2210.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

class FilePickerResultsList extends StatelessWidget {
  const FilePickerResultsList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.50,
      child: ListView.separated(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        separatorBuilder: (BuildContext context, int index) => const Divider(),
      ),
    );
  }
}
