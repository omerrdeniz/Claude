import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One row of mutually exclusive choices, with a line underneath saying what
/// the current one means.
///
/// Difficulty, speed and tolerance were three all but identical widgets
/// before this: the same column, row, chips and caption, differing only in
/// what they were choosing between. [labelOf] and [caption] are what actually
/// varied.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.caption,
    required this.onChanged,
  });

  final List<T> options;
  final T selected;

  /// What to write on the chip for an option.
  final String Function(T) labelOf;

  /// What the chosen option means, in the player's terms.
  final String caption;

  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final option in options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: labelOf(option),
                    selected: option == selected,
                    onTap: () => onChanged(option),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// One on-off setting, with a line saying what it currently means.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;

  /// What the setting means in the state it is in — not what it is called.
  final String subtitle;

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppTheme.accentSoft,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Nudges when the game thinks a tap happened.
///
/// The device is asked how far behind its own audio is and that is used
/// automatically, but no device knows the whole answer: not what Bluetooth
/// adds, and not the player's own hand, which arrives a little after the eye
/// says to move. This is the part only the person playing can supply.
///
/// The sign is written out rather than left as a number, because "+40 ms" is
/// meaningless to anyone who has not built a rhythm game.
class LatencyPicker extends StatelessWidget {
  const LatencyPicker({
    super.key,
    required this.offsetMs,
    required this.onChanged,
    required this.step,
    required this.onMeasure,
  });

  final double offsetMs;
  final ValueChanged<double> onChanged;
  final double step;

  /// Opens the screen that works the number out by ear, which is the only
  /// way anyone finds it: a perfect hit is a window 55 ms wide, and the
  /// buttons either side of this move in tens.
  final VoidCallback onMeasure;

  @override
  Widget build(BuildContext context) {
    final rounded = offsetMs.round();
    final description = rounded == 0
        ? 'Cihazın bildirdiği gecikme kullanılıyor'
        : rounded > 0
            ? 'Dokunuşların $rounded ms erken sayılıyor'
            : 'Dokunuşların ${-rounded} ms geç sayılıyor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Zamanlama ayarı',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            _StepButton(
              icon: Icons.remove,
              onTap: () => onChanged(offsetMs - step),
            ),
            SizedBox(
              width: 68,
              child: Text(
                '${rounded > 0 ? '+' : ''}$rounded ms',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: () => onChanged(offsetMs + step),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Her şey geç sayılıyorsa artırın',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            TextButton(
              onPressed: onMeasure,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Ölç',
                  style: TextStyle(fontSize: 13, color: AppTheme.accentSoft)),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

/// A selectable pill.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.accent.withValues(alpha: 0.30)
          : AppTheme.surface.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.accentSoft : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
