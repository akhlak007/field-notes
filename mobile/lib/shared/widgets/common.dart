import 'package:field_notes/core/constants.dart';
import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  static const asset = 'assets/field_notes_logo.svg';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) => SyncStatusBar(
        state: state,
        onRetry: () => context.read<SyncBloc>().add(const SyncRequested()),
      ),
    );
  }
}

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key, required this.state, this.onRetry});

  final SyncState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = state.error != null;
    return Material(
      color: error
          ? scheme.errorContainer
          : state.online
          ? scheme.surface
          : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(
              _icon(state),
              size: 18,
              color: error ? scheme.onErrorContainer : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.error ?? state.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: error ? scheme.onErrorContainer : null),
              ),
            ),
            if (state.error != null && state.online)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  IconData _icon(SyncState state) {
    if (!state.online) return Icons.cloud_off;
    if (state.syncing) return Icons.sync;
    if (state.pending > 0) return Icons.cloud_upload_outlined;
    return Icons.cloud_done_outlined;
  }
}

class SyncPill extends StatelessWidget {
  const SyncPill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        final error = state.error != null;
        final bg = error
            ? Theme.of(context).colorScheme.errorContainer
            : !state.online
            ? const Color(0xFFE8E4D8)
            : AppColors.syncedBg;
        final fg = error
            ? Theme.of(context).colorScheme.onErrorContainer
            : !state.online
            ? AppColors.ink
            : AppColors.syncedFg;
        return Material(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: error && state.online
                ? () => context.read<SyncBloc>().add(const SyncRequested())
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                error ? 'Failed · Retry' : state.label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SyncChip extends SyncPill {
  const SyncChip({super.key});
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appMuted(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class HomeTabBar extends StatelessWidget {
  const HomeTabBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: dark
                    ? Theme.of(context).colorScheme.outlineVariant
                    : AppColors.line,
              ),
            ),
          ),
          child: Row(
            children: [
              _tab(context, 0, 'Notes'),
              _tab(context, 1, 'Customers'),
              _tab(context, 2, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int value, String label) {
    final selected = index == value;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 15,
              color: selected ? appAccent(context) : appMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.syncedBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: appMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.label,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.onTap,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final String? label;
  final IconData? icon;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: appMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: appAccent(context)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: appMuted(context)),
              ),
            ],
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusBackground(status),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class StatusPills extends StatelessWidget {
  const StatusPills({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String)>[
      if (allowAll) (null, 'All'),
      for (final status in noteStatuses) (status, statusFilterLabel(status)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _pill(
              context,
              items[i].$2,
              value == items[i].$1,
              () => onChanged(items[i].$1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Material(
      color: selected
          ? AppColors.primary
          : Theme.of(context).colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : appOutline(context),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : appInk(context),
            ),
          ),
        ),
      ),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.siteChipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.siteChipFg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ContentWidth extends ResponsiveBody {
  const ContentWidth({
    super.key,
    required super.child,
    super.maxWidth,
    super.padding,
  });
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
  });

  final TextEditingController? controller;
  final String? hint;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: appMuted(context), fontWeight: FontWeight.w600),
      ),
    );
  }
}

class TappableField extends StatelessWidget {
  const TappableField({
    super.key,
    required this.text,
    required this.onTap,
    this.muted = false,
    this.onClear,
  });

  final String text;
  final VoidCallback onTap;
  final bool muted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: appOutline(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: muted ? appMuted(context) : appInk(context),
                    ),
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomBarButton extends StatelessWidget {
  const BottomBarButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: PrimaryButton(label: label, onPressed: onPressed),
      ),
    );
  }
}

class SiteChip extends StatelessWidget {
  const SiteChip({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return CountChip(label: '$count ${count == 1 ? 'site' : 'sites'}');
  }
}

String relativeNoteTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(local.year, local.month, local.day);
  final diff = today.difference(that).inDays;
  final time = DateFormat('HH:mm').format(local);
  if (diff == 0) return 'Today $time';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEE').format(local);
  return DateFormat('MMM d').format(local);
}

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showPermissionMessage(
  BuildContext context,
  String message, {
  required bool openSettings,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: openSettings
          ? SnackBarAction(label: 'Open settings', onPressed: openAppSettings)
          : null,
    ),
  );
}
