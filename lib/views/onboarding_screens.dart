import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/theme.dart';
import '../data/content_data.dart';
import '../models/models.dart';
import '../viewmodels/goal_view_model.dart';
import '../viewmodels/notifications_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'widgets/common.dart';
import 'widgets/wellness.dart';

/// S01 Chào mừng.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageList(
          children: [
            const Row(
              children: [
                Expanded(child: BrandTitle()),
                DemoPill(),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            const RoundedImage(bowlImage, height: 220),
            const SizedBox(height: AppSpace.xl),
            const Text(
              'Ăn uống chủ động, mỗi ngày một chút',
              style: AppText.title,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Ghi nhận bữa ăn, tìm hiểu kiến thức và lên kế hoạch theo nhịp sống của bạn.',
              style: AppText.body.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomCta(
        child: FilledButton(
          key: const Key('welcome-start'),
          onPressed: () => context.go('/goals'),
          child: const Text('Bắt đầu →'),
        ),
      ),
    );
  }
}

/// S10 Đăng nhập. Màn thêm cho Lab 3, Lab 2 không có màn này.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final local = context.read<AppServices>().isLocal;
    return Theme(
      data: Wellness.theme(context),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !session.isSigningIn) {
            session.clearMessage();
            context.go('/welcome');
          }
        },
        child: Scaffold(
          appBar: WellnessHeader(
            title: 'Đăng nhập',
            onBack: session.isSigningIn
                ? null
                : () {
                    session.clearMessage();
                    context.go('/welcome');
                  },
          ),
          body: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 150,
                child: IgnorePointer(
                  child: CustomPaint(painter: BotanicalPainter()),
                ),
              ),
              PageList(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1.9,
                      child: Image.asset(
                        bowlImage,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const LeafBrand(),
                  const SizedBox(height: 20),
                  Text(
                    local
                        ? 'Bắt đầu với hồ sơ trên điện thoại'
                        : 'Lưu nhật ký theo tài khoản của bạn',
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 390
                          ? 31
                          : 35,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      color: Wellness.forest,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 72,
                      height: 12,
                      child: CustomPaint(painter: _LoginUnderline()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    local
                        ? 'Ghi bữa ăn và kế hoạch ngay cả khi không có mạng. Dữ liệu chỉ lưu trên máy này. Chưa kết nối Google hoặc Firebase.'
                        : 'Đăng nhập để dữ liệu bữa ăn và kế hoạch của bạn được tách riêng trên thiết bị này, giúp bạn đồng hành lâu dài và liền mạch hơn.',
                    style: Wellness.body.copyWith(fontSize: 17, height: 1.5),
                  ),
                  const SizedBox(height: 65),
                ],
              ),
            ],
          ),
          bottomNavigationBar: BottomCta(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session.message != null) ...[
                  StatusBanner(
                    key: const Key('login-message'),
                    kind: BannerKind.error,
                    message: session.message!,
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
                FilledButton.icon(
                  key: const Key('login-google'),
                  onPressed: session.isSigningIn ? null : session.signIn,
                  icon: session.isSigningIn
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Wellness.muted,
                          ),
                        )
                      : local
                      ? const Icon(Icons.phone_android)
                      : const GoogleMark(),
                  label: Text(
                    session.isSigningIn
                        ? 'Đang mở…'
                        : local
                        ? 'Tiếp tục offline'
                        : 'Tiếp tục với Google',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginUnderline extends CustomPainter {
  const _LoginUnderline();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(2, size.height - 2)
      ..quadraticBezierTo(
        size.width * .5,
        0,
        size.width - 2,
        size.height * .45,
      ),
    Paint()
      ..color = const Color(0xFFA9BC83)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// S02 Chọn mục tiêu. Từ Tài khoản mở với `edit=true` để đổi mục tiêu.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key, required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SessionViewModel>().uid!;
    return ChangeNotifierProvider(
      create: (_) => GoalViewModel(
        context.read<AppServices>(),
        context.read<SessionViewModel>(),
        uid,
        isEditing: isEditing,
      ),
      child: const _GoalsView(),
    );
  }
}

const _goalIcons = {
  Goal.logMeals: Icons.restaurant_menu,
  Goal.planMeals: Icons.calendar_month_outlined,
  Goal.learn: Icons.menu_book_outlined,
};

class _GoalsView extends StatelessWidget {
  const _GoalsView();

  Future<void> _submit(BuildContext context, GoalViewModel vm) async {
    final saved = await vm.submit();
    if (!saved || !context.mounted) return;
    if (vm.isEditing) {
      context.pop();
    } else {
      context.read<NotificationsViewModel>().requestAfterOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoalViewModel>();
    return PopScope(
      canPop: vm.isEditing && !vm.saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !vm.saving && !vm.isEditing) context.go('/welcome');
      },
      child: Scaffold(
        appBar: BackAppBar(
          title: vm.isEditing ? 'Đổi mục tiêu' : 'Longevity Plate',
          showDemoPill: true,
        ),
        body: PageList(
          children: [
            const Text('Bạn muốn bắt đầu từ đâu?', style: AppText.title),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Chọn ít nhất một điều bạn muốn tập trung.',
              style: AppText.body.copyWith(color: AppColors.muted),
            ),
            if (vm.showRequiredError)
              const FieldError('Hãy chọn ít nhất một mục tiêu.'),
            const SizedBox(height: AppSpace.lg),
            for (final goal in Goal.values) ...[
              _GoalCard(
                goal: goal,
                selected: vm.selected.contains(goal),
                onTap: vm.saving ? null : () => vm.toggle(goal),
              ),
              const SizedBox(height: AppSpace.md),
            ],
            if (!vm.isEditing)
              const StatusBanner(
                kind: BannerKind.info,
                message: 'Bạn có thể thay đổi mục tiêu bất kỳ lúc nào trong phần cài đặt cá nhân sau khi bắt đầu.',
              ),
          ],
        ),
        bottomNavigationBar: BottomCta(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vm.saveFailed) ...[
                const StatusBanner(
                  key: Key('goal-save-error'),
                  kind: BannerKind.error,
                  message: 'Chưa lưu được mục tiêu.',
                  detail: 'Lựa chọn vẫn được giữ. Bấm Hoàn tất để thử lại.',
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              FilledButton(
                key: const Key('goals-submit'),
                onPressed: vm.saving ? null : () => _submit(context, vm),
                child: vm.saving
                    ? const SavingButtonChild('Đang lưu…')
                    : const Text('Hoàn tất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      child: AppCard(
        key: Key('goal-${goal.name}'),
        onTap: onTap,
        borderColor: selected ? AppColors.primary : null,
        color: selected ? AppColors.selected : AppColors.surface,
        child: Row(
          children: [
            IconTile(_goalIcons[goal]!),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.label, style: AppText.label),
                  if (selected)
                    Text(
                      'Đã chọn',
                      style: AppText.caption.copyWith(color: AppColors.primary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
