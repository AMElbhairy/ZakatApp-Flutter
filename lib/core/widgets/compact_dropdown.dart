import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import 'compact_selection_dialog.dart';
import 'responsive_layout.dart';

typedef CompactDropdownLabelBuilder<T> = String Function(T value);

class CompactDropdownFormField<T> extends StatelessWidget {
  const CompactDropdownFormField({
    super.key,
    required this.value,
    required this.labelText,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.floatingLabelBehavior = FloatingLabelBehavior.always,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 16,
    ),
    this.textStyle,
  });

  final T? value;
  final String labelText;
  final List<T> items;
  final CompactDropdownLabelBuilder<T> itemLabel;
  final ValueChanged<T> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final FloatingLabelBehavior floatingLabelBehavior;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<T> field) {
        final T currentValue = field.value ?? value ?? items.first;
        return InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            floatingLabelBehavior: floatingLabelBehavior,
            contentPadding: contentPadding,
            errorText: field.errorText,
          ),
          child: PressScale(
            enabled: enabled,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled
                  ? () async {
                      final T? selected =
                          await showCompactSelectionDialogAfterFocus<T>(
                            context: context,
                            title: labelText,
                            options: items,
                            optionLabel: itemLabel,
                            selectedValueLabel: itemLabel(currentValue),
                          );
                      if (selected != null) {
                        field.didChange(selected);
                        onChanged(selected);
                      }
                    }
                  : null,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      itemLabel(currentValue),
                      style: textStyle ?? Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CompactDropdownButton<T> extends StatelessWidget {
  const CompactDropdownButton({
    super.key,
    required this.value,
    required this.labelText,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final String labelText;
  final List<T> items;
  final CompactDropdownLabelBuilder<T> itemLabel;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool compact = ResponsiveLayout.isCompact(context);
    return PressScale(
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () async {
                final T? selected =
                    await showCompactSelectionDialogAfterFocus<T>(
                      context: context,
                      title: labelText,
                      options: items,
                      optionLabel: itemLabel,
                      selectedValueLabel: itemLabel(value),
                    );
                if (selected != null) onChanged(selected);
              }
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: compact ? 3 : 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  itemLabel(value),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: compact ? 2 : 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: compact ? 16 : 18),
            ],
          ),
        ),
      ),
    );
  }
}
