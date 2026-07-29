import 'package:clipmind/features/providers/presentation/widgets/dynamic_model_selector.dart';
import 'package:flutter/widgets.dart';

/// Legacy public API retained for editor callers; options now come from the
/// persisted provider profile rather than a presentation-level static list.
class ModelSelectorDropdown extends StatelessWidget {
  const ModelSelectorDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return const DynamicModelSelector();
  }
}
