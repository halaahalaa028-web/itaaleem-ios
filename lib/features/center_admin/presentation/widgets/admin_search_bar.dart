import 'dart:async';

import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';

/// Debounced search field — calls [onChanged] 400ms after typing stops.
class AdminSearchBar extends StatefulWidget {
  const AdminSearchBar({
    super.key,
    required this.onChanged,
    this.hint = 'ابحث...',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => widget.onChanged(value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  _changed('');
                },
              ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
