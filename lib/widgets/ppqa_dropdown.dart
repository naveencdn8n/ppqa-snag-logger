import 'package:flutter/material.dart';

/// A generic, reusable dropdown form field for the PPQA app.
///
/// Usage:
/// ```dart
/// PPQADropdown<SnagSeverity>(
///   label: 'Severity',
///   value: _severity,
///   items: SnagSeverity.values,
///   labelBuilder: (s) => s.label,
///   itemColorBuilder: (s) => s.color,   // optional — shows a dot
///   onChanged: (val) => setState(() => _severity = val),
///   validator: (val) => val == null ? 'Required' : null,
/// )
/// ```
class PPQADropdown<T> extends StatelessWidget {
  const PPQADropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.itemColorBuilder,
    this.validator,
    this.isRequired = false,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final Color Function(T)? itemColorBuilder;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: value,
      validator: validator,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
      ),
      items: items.map((item) {
        final dotColor = itemColorBuilder?.call(item);
        return DropdownMenuItem<T>(
          value: item,
          child: Row(
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  labelBuilder(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
