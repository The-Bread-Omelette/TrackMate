import 'package:flutter/material.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../theme/app_theme.dart';

class RoleSelector extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  const RoleSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: UserRole.values.map((role) {
        final isSelected = role == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _RoleTile(
              role: role,
              isSelected: isSelected,
              onTap: () => onChanged(role),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final UserRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (role) {
      case UserRole.trainee:
        return Icons.person_outline_rounded;
      case UserRole.trainer:
        return Icons.fitness_center_rounded;
      case UserRole.admin:
        return Icons.shield_outlined;
    }
  }

  String get _label {
    switch (role) {
      case UserRole.trainee:
        return 'User';
      case UserRole.trainer:
        return 'Trainer';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
