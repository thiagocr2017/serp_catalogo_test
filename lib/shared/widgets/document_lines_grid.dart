import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DocumentLinesGridColumn {
  const DocumentLinesGridColumn({required this.label, required this.width});

  final String label;
  final double width;
}

typedef DocumentLineCellsBuilder = List<Widget> Function(
  int index,
  bool selected,
  VoidCallback select,
);

double calculateDocumentLineSubtotal({
  required int quantity,
  required double unitPrice,
  double discountPercent = 0,
}) {
  final discount = discountPercent.clamp(0, 100) / 100;
  return quantity * unitPrice * (1 - discount);
}

class DocumentLinesGrid extends StatefulWidget {
  const DocumentLinesGrid({
    required this.searchField,
    required this.focusSearch,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    required this.onAddLine,
    required this.onRemoveLine,
    required this.emptyState,
    this.addLineEnabled = true,
    this.showCaptureControls = true,
    this.footerLabel = 'Busque o escanee un producto; Enter lo agrega. Insert enfoca esta búsqueda.',
    super.key,
  });

  final Widget searchField;
  final VoidCallback focusSearch;
  final List<DocumentLinesGridColumn> columns;
  final int rowCount;
  final DocumentLineCellsBuilder rowBuilder;
  final VoidCallback onAddLine;
  final ValueChanged<int> onRemoveLine;
  final Widget emptyState;
  final bool addLineEnabled;
  final bool showCaptureControls;
  final String footerLabel;

  @override
  State<DocumentLinesGrid> createState() => _DocumentLinesGridState();
}

class _DocumentLinesGridState extends State<DocumentLinesGrid> {
  int? _selectedIndex;
  final Map<int, FocusNode> _rowFocusNodes = {};

  bool get _textEditorHasFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.widget is TextField ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext.findAncestorWidgetOfExactType<TextField>() != null;
  }

  @override
  void dispose() {
    for (final focus in _rowFocusNodes.values) {
      focus.dispose();
    }
    super.dispose();
  }

  void _selectRow(int index) {
    setState(() => _selectedIndex = index);
    FocusScope.of(context)
        .requestFocus(_rowFocusNodes.putIfAbsent(index, FocusNode.new));
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.f2 && widget.addLineEnabled) {
      widget.focusSearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.insert &&
        widget.addLineEnabled) {
      widget.onAddLine();
      widget.focusSearch();
      return KeyEventResult.handled;
    }
    if (_textEditorHasFocus) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final index = _selectedIndex;
      if (index != null && index < widget.rowCount) {
        widget.onRemoveLine(index);
        setState(() => _selectedIndex = null);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Focus(
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showCaptureControls)
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;
                final search = Row(
                  children: [
                    const Icon(Icons.qr_code_2_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: widget.searchField),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Enfocar búsqueda para el lector físico',
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Text('F2 / Lector'),
                        ),
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.focusSearch,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Lector óptico'),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 10), actions],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          if (widget.showCaptureControls) const SizedBox(height: 12),
          if (widget.rowCount == 0)
            widget.emptyState
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        for (final column in widget.columns)
                          Expanded(
                            flex: (column.width * 100).round(),
                            child: Container(
                              height: 36,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              color: colors.surfaceContainerLow,
                              child: Text(
                                column.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (var index = 0; index < widget.rowCount; index++)
                    _buildRow(context, index, colors),
                  Divider(height: 1, color: colors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.footerLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, ColorScheme colors) {
    final selected = _selectedIndex == index;
    final cells = widget.rowBuilder(index, selected, () => _selectRow(index));
    return Focus(
      focusNode: _rowFocusNodes.putIfAbsent(index, FocusNode.new),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || _selectedIndex != index) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey != LogicalKeyboardKey.delete &&
            event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }
        if (_textEditorHasFocus) return KeyEventResult.ignored;
        widget.onRemoveLine(index);
        setState(() => _selectedIndex = null);
        return KeyEventResult.handled;
      },
      onFocusChange: (hasFocus) {
        if (hasFocus && _selectedIndex != index) {
          setState(() => _selectedIndex = index);
        }
      },
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            color: selected ? colors.surfaceContainerHighest : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var column = 0; column < widget.columns.length; column++)
                  Expanded(
                    flex: (widget.columns[column].width * 100).round(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: column < cells.length
                          ? column == widget.columns.length - 1
                                ? Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent &&
                                          widget.addLineEnabled) {
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.tab ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.enter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey
                                                    .numpadEnter) {
                                          widget.focusSearch();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: cells[column],
                                  )
                                : cells[column]
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
        ],
      ),
    );
  }
}
