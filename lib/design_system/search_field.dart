import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// The pill search field (board 2): 52dp, `surfaceContainer`, 1px outline,
/// 1.5px `primary` while focused, a clear button once there is text, and an
/// optional trailing count ("3 of 14").
class SearchField extends StatefulWidget {
  const SearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.trailing,
    this.onSubmitted,
    this.height = 52,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final Widget? trailing;
  final double height;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    _controller.removeListener(_rebuild);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      constraints: BoxConstraints(minHeight: widget.height),
      padding: EdgeInsets.only(left: 18, right: _controller.text.isEmpty && widget.trailing == null ? 18 : 2),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(widget.height),
        border: Border.all(color: focused ? c.primary : c.outline, width: focused ? 1.5 : 1),
      ),
      child: Row(
        spacing: 12,
        children: <Widget>[
          AppIcon(AppIcons.search, color: c.icon),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: UnfurlType.body.copyWith(height: 1.3, color: c.onSurface),
              cursorColor: c.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: UnfurlType.body.copyWith(height: 1.3, color: c.onSurfaceVariant),
              ),
            ),
          ),
          ?widget.trailing,
          if (_controller.text.isNotEmpty)
            AppIconButton(
              icon: AppIcons.close,
              filled: false,
              semanticLabel: 'Clear search',
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

/// A [TextEditingController] that lives as long as the widget: for text fields
/// in sheets and dialogs, whose content outlives the call that showed them
/// (it is still on screen while the sheet animates away).
class TextControllerScope extends StatefulWidget {
  const TextControllerScope({required this.builder, this.initial, super.key});

  final String? initial;
  final Widget Function(BuildContext context, TextEditingController controller) builder;

  @override
  State<TextControllerScope> createState() => _TextControllerScopeState();
}

class _TextControllerScopeState extends State<TextControllerScope> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}
