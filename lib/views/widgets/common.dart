import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../viewmodels/notifications_view_model.dart';

const maxContentWidth = 600.0;

double pageMargin(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > maxContentWidth + 32
      ? (width - maxContentWidth) / 2
      : AppSpace.lg;
}

/// Danh sách cuộn với lề 16 và giới hạn rộng 600 trên màn lớn.
class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.controller});

  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final margin = pageMargin(context);
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(margin, AppSpace.lg, margin, AppSpace.xl),
      children: children,
    );
  }
}

/// Nút chính ghim ở cuối màn.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final margin = pageMargin(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margin,
          AppSpace.sm,
          margin,
          AppSpace.lg,
        ),
        child: child,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.borderColor,
    this.color = AppColors.surface,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: cardShadow,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.selected,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: AppText.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class DemoPill extends StatelessWidget {
  const DemoPill({super.key, this.label = 'Dữ liệu minh họa'});

  final String label;

  @override
  Widget build(BuildContext context) => Pill(label, icon: Icons.info_outline);
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.selected,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Icon(icon, color: AppColors.primary),
    );
  }
}

class RoundedImage extends StatelessWidget {
  const RoundedImage(this.asset, {super.key, this.height = 180, this.width});

  final String asset;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Image.asset(
        asset,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Longevity Plate',
      style: AppText.heading.copyWith(color: AppColors.primary),
    );
  }
}

/// Header của 4 tab: brand, chuông thông báo và tài khoản.
class RootAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RootAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsViewModel, int>(
      (vm) => vm.unreadCount,
    );
    return AppBar(
      title: const BrandTitle(),
      actions: [
        IconButton(
          key: const Key('open-notifications'),
          tooltip: unread > 0 ? 'Thông báo, $unread chưa đọc' : 'Thông báo',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          key: const Key('open-account'),
          tooltip: 'Tài khoản',
          onPressed: () => context.push('/account'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
        const SizedBox(width: AppSpace.xs),
      ],
    );
  }
}

/// Header màn con. Back đi qua maybePop để PopScope của màn được hỏi trước.
class BackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BackAppBar({super.key, required this.title, this.showDemoPill = false});

  final String title;
  final bool showDemoPill;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(title),
      actions: [
        if (showDemoPill)
          const Padding(
            padding: EdgeInsets.only(right: AppSpace.lg),
            child: Center(child: Pill('Minh họa')),
          ),
      ],
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView(this.message, {super.key, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpace.lg),
              Text(message, style: AppText.label, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(detail!, style: AppText.caption, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: pageMargin(context),
          vertical: AppSpace.xl,
        ),
        child: Semantics(
          liveRegion: isError,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: isError ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(title, style: AppText.heading, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.sm),
              Text(body, style: AppText.caption, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpace.lg),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      icon: Icons.cloud_off_outlined,
      title: title,
      body: body,
      actionLabel: 'Thử lại',
      onAction: onRetry,
      isError: true,
    );
  }
}

enum BannerKind { success, error, info }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.kind,
    required this.message,
    this.detail,
    this.actions = const [],
  });

  final BannerKind kind;
  final String message;
  final String? detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final (icon, color, surface) = switch (kind) {
      BannerKind.success => (
        Icons.check_circle_outline,
        AppColors.primary,
        AppColors.selected,
      ),
      BannerKind.error => (
        Icons.error_outline,
        AppColors.error,
        AppColors.errorSurface,
      ),
      BannerKind.info => (
        Icons.info_outline,
        AppColors.primary,
        AppColors.surface,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(message, style: AppText.label)),
              ],
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpace.xs),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(detail!, style: AppText.caption),
              ),
            ],
            if (actions.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: AppSpace.sm, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lỗi trường nhập: có icon và chữ, không chỉ dựa vào màu.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 20, color: AppColors.error),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                message,
                style: AppText.caption.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavingButtonChild extends StatelessWidget {
  const SavingButtonChild(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpace.sm),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// Lựa chọn dạng nút: khi chọn có viền đậm và dấu tích, không chỉ đổi màu.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isRadio = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool isRadio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: isRadio,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.selected : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpace.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.label.copyWith(
                    color: selected ? AppColors.primary : AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
