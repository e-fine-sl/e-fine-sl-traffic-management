import 'package:flutter/material.dart';

/// A selectable card that represents a single accident type option.
///
/// Uses Material Icons instead of emojis for a consistent, professional look
/// across all devices and platforms.
class AccidentTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const AccidentTypeCard({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryAccent = const Color(0xFFC62828); // Deep red
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: primaryAccent.withAlpha(25),
        highlightColor: primaryAccent.withAlpha(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryAccent.withAlpha(15)
                : isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryAccent : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryAccent.withAlpha(20)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? primaryAccent : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? primaryAccent
                            : isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? primaryAccent.withAlpha(180)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        color: primaryAccent,
                        size: 22,
                      )
                    : Icon(
                        Icons.radio_button_unchecked_rounded,
                        key: const ValueKey('unselected'),
                        color: Colors.grey.shade300,
                        size: 22,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
