import 'package:flutter/material.dart';

/// Owns text controllers for a dialog subtree until its route is fully removed.
///
/// Dialog results can complete when the route starts closing, before its text
/// fields are detached. Keeping disposal in this subtree avoids disposing a
/// controller while a TextField still listens to it.
class DialogTextControllerOwner extends StatefulWidget {
  const DialogTextControllerOwner({
    required this.count,
    required this.builder,
    this.initialValues = const [],
    super.key,
  });

  final int count;
  final List<String> initialValues;
  final Widget Function(
    BuildContext context,
    List<TextEditingController> controllers,
  ) builder;

  @override
  State<DialogTextControllerOwner> createState() =>
      _DialogTextControllerOwnerState();
}

class _DialogTextControllerOwnerState extends State<DialogTextControllerOwner> {
  late final List<TextEditingController> _controllers = List.generate(
    widget.count,
    (index) => TextEditingController(
      text: index < widget.initialValues.length
          ? widget.initialValues[index]
          : '',
    ),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}
