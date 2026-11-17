import 'package:flutter/material.dart';

import '../../app/theme.dart';

class TutorVisualAid extends StatelessWidget {
  const TutorVisualAid({super.key, required this.topic});

  final String topic;

  static bool supports(String topic) {
    final value = topic.toLowerCase();
    return value.contains('loop') ||
        value.contains('function') ||
        value.contains('condition') ||
        value.contains('if statement') ||
        value.contains('list');
  }

  @override
  Widget build(BuildContext context) {
    final value = topic.toLowerCase();
    final List<String> steps;
    final String label;
    if (value.contains('loop')) {
      label = 'A loop repeats a small sequence';
      steps = const <String>['Choose item', 'Run the code', 'Next item'];
    } else if (value.contains('function')) {
      label = 'A function takes inputs and can return a result';
      steps = const <String>['Call', 'Use inputs', 'Return'];
    } else if (value.contains('list')) {
      label = 'A list keeps items in order';
      steps = const <String>['0 · apple', '1 · banana', '2 · mango'];
    } else {
      label = 'A condition chooses which path runs';
      steps = const <String>[
        'Check condition',
        'True · run block',
        'False · skip',
      ];
    }

    return Semantics(
      label: 'Visual explanation. $label. ${steps.join(', then ')}.',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SkillBridgeColors.codeSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SkillBridgeColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUICK PICTURE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SkillBridgeColors.primary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  _VisualStep(label: steps[index], highlighted: index == 0),
                  if (index < steps.length - 1)
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: SkillBridgeColors.textMuted,
                      semanticLabel: 'then',
                    ),
                ],
              ],
            ),
            if (value.contains('loop')) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '↶ repeat for each item',
                  style: TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisualStep extends StatelessWidget {
  const _VisualStep({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? SkillBridgeColors.primary.withValues(alpha: 0.14)
            : SkillBridgeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted
              ? SkillBridgeColors.textPrimary
              : SkillBridgeColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
