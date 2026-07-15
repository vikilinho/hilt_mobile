import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../hydration_manager.dart';
import '../l10n/app_localizations.dart';
import '../services/hydration_reminder_service.dart';

const int _mlPerCup = 200;
const Color _hiltTeal = Color(0xFF00897B);
const Color _hydrationDeepTeal = Color(0xFF0B5E55);
const Color _hydrationMint = Color(0xFFDFF3EE);
const Color _hydrationGlow = Color(0xFF7FD4C6);
const Color _hydrationText = Color(0xFF123F39);
const Color _hydrationSubtleText = Color(0xFF4B6A65);

class HydrationScreen extends StatelessWidget {
  const HydrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hydration = context.watch<HydrationManager>();
    final theme = Theme.of(context);

    if (hydration.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF6FCF9),
            Color(0xFFE6F5EF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            context.l10n.text('hydrationGarden'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _hydrationText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.text('growYourPlant'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _hydrationSubtleText,
            ),
          ),
          const SizedBox(height: 20),
          _HydrationHeroCard(manager: hydration),
          const SizedBox(height: 16),
          _QuickAddRow(
            onAddWater: hydration.addWater,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  label: context.l10n.text('consumed'),
                  value: _formatCupValue(context, hydration.dailyTotalMl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryChip(
                  label: context.l10n.text('remaining'),
                  value: _formatCupValue(context, hydration.remainingMl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryChip(
                  label: context.l10n.text('streak'),
                  value: context.l10n.dayStreak(hydration.currentStreak),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReminderCard(
            enabled: hydration.remindersEnabled,
            isUpdating: hydration.isUpdatingReminders,
            onToggle: (enabled) async {
              final result = await hydration.toggleSmartReminders(enabled);
              if (!context.mounted) return;

              final messenger = ScaffoldMessenger.of(context);
              messenger.hideCurrentSnackBar();

              switch (result) {
                case HydrationReminderEnableResult.enabled:
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.text('smartRemindersOn')),
                    ),
                  );
                  break;
                case HydrationReminderEnableResult.disabled:
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.text('smartRemindersOff')),
                    ),
                  );
                  break;
                case HydrationReminderEnableResult.denied:
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.text('notificationPermissionDenied'),
                      ),
                    ),
                  );
                  break;
                case HydrationReminderEnableResult.exactAlarmDenied:
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.text('exactAlarmDenied'),
                      ),
                    ),
                  );
                  break;
                case HydrationReminderEnableResult.unavailable:
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.text('notificationsUnavailable'),
                      ),
                    ),
                  );
                  break;
              }
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                context.l10n.text('todaysIntake'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _hydrationText,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE, MMM d', context.l10n.localeTag).format(DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF67817C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hydration.entries.isEmpty)
            const _HydrationEmptyState()
          else
            ...hydration.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey('hydration_entry_${entry.id}'),
                  direction: DismissDirection.endToStart,
                  background: const _DeleteBackground(),
                  onDismissed: (_) => hydration.deleteEntry(entry.id),
                  child: _HydrationEntryTile(
                    amountMl: entry.amountMl,
                    timestamp: entry.timestamp,
                    onDelete: () => hydration.deleteEntry(entry.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.enabled,
    required this.isUpdating,
    required this.onToggle,
  });

  final bool enabled;
  final bool isUpdating;
  final Future<void> Function(bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = defaultTargetPlatform;
    final isAndroid = platform == TargetPlatform.android;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _hydrationMint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _hydrationMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: _hiltTeal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.text('smartReminders'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _hydrationText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.text('nudgesEvery2Hours'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _hydrationSubtleText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isAndroid)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isUpdating
                  ? null
                  : () async {
                      await onToggle(!enabled);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: isUpdating
                    ? const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(
                        enabled
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        size: 42,
                        color: enabled ? _hiltTeal : const Color(0xFF9AB9B2),
                      ),
              ),
            )
          else
            Switch.adaptive(
              value: enabled,
              activeThumbColor: _hiltTeal,
              onChanged: isUpdating
                  ? null
                  : (value) async {
                      await onToggle(value);
                    },
            ),
        ],
      ),
    );
  }
}

class _HydrationHeroCard extends StatefulWidget {
  const _HydrationHeroCard({required this.manager});

  final HydrationManager manager;

  @override
  State<_HydrationHeroCard> createState() => _HydrationHeroCardState();
}

class _HydrationHeroCardState extends State<_HydrationHeroCard>
    with TickerProviderStateMixin {
  late final AnimationController _reactionController;
  late final AnimationController _idleController;
  late final AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final initialProgress = _cappedProgress(widget.manager.progress);
    _progressAnimation = AlwaysStoppedAnimation(initialProgress);
  }

  @override
  void didUpdateWidget(covariant _HydrationHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.manager.dailyTotalMl > oldWidget.manager.dailyTotalMl) {
      final crossedGoal = oldWidget.manager.dailyTotalMl <
              oldWidget.manager.dailyGoalMl &&
          widget.manager.dailyTotalMl >= widget.manager.dailyGoalMl;
      if (crossedGoal) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      _reactionController.forward(from: 0);
    }

    final nextProgress = _cappedProgress(widget.manager.progress);
    final currentProgress = _progressAnimation.value;
    if ((nextProgress - currentProgress).abs() > 0.0001) {
      _progressAnimation = Tween<double>(
        begin: currentProgress,
        end: nextProgress,
      ).animate(
        CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeOutCubic,
        ),
      );
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reactionController.dispose();
    _idleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = widget.manager;
    final stage = _PlantStage.fromProgress(manager.progress);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      height: 352,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFFFF),
            stage.accent.withValues(alpha: 0.14),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _hiltTeal.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -8,
            right: -12,
            child: _Orb(
              size: 104,
              color: stage.accent.withValues(alpha: 0.16),
            ),
          ),
          const Positioned(
            bottom: 8,
            left: 16,
            child: _Orb(
              size: 68,
              color: Color(0x14A7D9C9),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _reactionController,
                builder: (context, child) {
                  final t = Curves.easeOut.transform(_reactionController.value);
                  return Opacity(
                    opacity: (1 - t) * 0.85,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: RadialGradient(
                          center: const Alignment(0, 0.15),
                          radius: 0.85 + (t * 0.45),
                          colors: [
                            stage.accent.withValues(alpha: 0.20 * (1 - t)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.text(stage.titleKey),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _hydrationText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.text(stage.subtitleKey),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _hydrationSubtleText,
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 180,
                  height: 172,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _reactionController,
                          _idleController,
                        ]),
                        builder: (context, child) {
                          final idleWave =
                              math.sin(_idleController.value * math.pi * 2);
                          final reactionLift = math.sin(
                            Curves.easeOutBack.transform(
                                  _reactionController.value,
                                ) *
                                math.pi,
                          );
                          final offsetY = (idleWave * 4) - (reactionLift * 10);
                          final rotation =
                              (idleWave * 0.018) + (reactionLift * 0.01);
                          final scale = 1 + (_reactionController.value * 0.06);

                          return Transform.translate(
                            offset: Offset(0, offsetY),
                            child: Transform.rotate(
                              angle: rotation,
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 550),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.92,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: SizedBox(
                            key: ValueKey(stage.name),
                            width: 160,
                            height: 160,
                            child: SvgPicture.string(
                              _buildPlantSvg(stage),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _reactionController,
                        builder: (context, child) {
                          final t = Curves.easeInOut.transform(
                            _reactionController.value,
                          );
                          final dropOpacity =
                              t < 0.78 ? 1.0 - (t * 0.5) : 0.0;
                          final dropY = -68 + (t * 108);
                          return IgnorePointer(
                            child: Opacity(
                              opacity: dropOpacity,
                              child: Transform.translate(
                                offset: Offset(0, dropY),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 24,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _hydrationGlow,
                                _hiltTeal,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: stage.accent.withValues(alpha: 0.24),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  final value = _progressAnimation.value;
                  final animatedPercent = (value * 100).round();
                  return Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            value: value,
                            backgroundColor: const Color(0xFFE6F0EC),
                            valueColor: AlwaysStoppedAnimation(stage.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '$animatedPercent%',
                          key: ValueKey(animatedPercent),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _hydrationText,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Text(
                  context.l10n.cupsToday(
                    manager.dailyTotalMl / _mlPerCup,
                    manager.dailyGoalMl / _mlPerCup,
                  ),
                  key: ValueKey('${manager.dailyTotalMl}_${manager.dailyGoalMl}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _hydrationSubtleText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _cappedProgress(double progress) {
    if (progress < 0) return 0;
    if (progress > 1) return 1;
    return progress;
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({required this.onAddWater});

  final Future<void> Function(int ml) onAddWater;

  @override
  Widget build(BuildContext context) {
    const amounts = [200, 400, 600];
    return Row(
      children: amounts
          .map(
            (amount) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: amount == amounts.last ? 0 : 10,
                ),
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  shadowColor: _hiltTeal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await HapticFeedback.selectionClick();
                      await onAddWater(amount);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _hydrationMint,
                      foregroundColor: _hydrationDeepTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      side: BorderSide(
                        color: _hiltTeal.withValues(alpha: 0.08),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      '+${context.l10n.cupLabel(amount / _mlPerCup)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _hydrationMint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B827E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _hydrationText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HydrationEntryTile extends StatelessWidget {
  const _HydrationEntryTile({
    required this.amountMl,
    required this.timestamp,
    required this.onDelete,
  });

  final int amountMl;
  final DateTime timestamp;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _hydrationMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: _hiltTeal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.cupDrank(amountMl / _mlPerCup),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _hydrationText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm(context.l10n.localeTag).format(timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF708782),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.text('deleteIntakeEntry'),
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFD75E5E),
            ),
          ),
        ],
      ),
    );
  }
}

class _HydrationEmptyState extends StatelessWidget {
  const _HydrationEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _hydrationMint),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _hydrationMint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              color: _hiltTeal,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.text('firstCupWaiting'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _hydrationSubtleText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Color(0xFFD75E5E),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

String _formatCupValue(BuildContext context, int amountMl) {
  return context.l10n.cupLabel(amountMl / _mlPerCup);
}

enum _PlantStage {
  seed(
    accent: Color(0xFF86BA9A),
    titleKey: 'seedling',
    subtitleKey: 'seedlingSubtitle',
  ),
  sprout(
    accent: Color(0xFF4BAE9B),
    titleKey: 'sprouting',
    subtitleKey: 'sproutingSubtitle',
  ),
  young(
    accent: Color(0xFF2A9D8F),
    titleKey: 'leafingUp',
    subtitleKey: 'leafingUpSubtitle',
  ),
  thriving(
    accent: _hiltTeal,
    titleKey: 'thriving',
    subtitleKey: 'thrivingSubtitle',
  ),
  blooming(
    accent: _hydrationDeepTeal,
    titleKey: 'blooming',
    subtitleKey: 'bloomingSubtitle',
  );

  const _PlantStage({
    required this.accent,
    required this.titleKey,
    required this.subtitleKey,
  });

  final Color accent;
  final String titleKey;
  final String subtitleKey;

  static _PlantStage fromProgress(double progress) {
    if (progress >= 1.0) return _PlantStage.blooming;
    if (progress >= 0.75) return _PlantStage.thriving;
    if (progress >= 0.5) return _PlantStage.young;
    if (progress >= 0.25) return _PlantStage.sprout;
    return _PlantStage.seed;
  }
}

String _buildPlantSvg(_PlantStage stage) {
  switch (stage) {
    case _PlantStage.seed:
      return '''
<svg viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="90" cy="154" rx="52" ry="10" fill="#D8ECE4"/>
  <rect x="58" y="100" width="64" height="44" rx="14" fill="#C98E66"/>
  <path d="M68 100h44c-3 16-13 26-22 26s-19-10-22-26Z" fill="#754C36"/>
  <ellipse cx="92" cy="94" rx="8" ry="11" fill="#86BA9A"/>
</svg>
''';
    case _PlantStage.sprout:
      return '''
<svg viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="90" cy="154" rx="52" ry="10" fill="#D8ECE4"/>
  <rect x="58" y="102" width="64" height="42" rx="14" fill="#C98E66"/>
  <path d="M68 102h44c-3 15-13 25-22 25s-19-10-22-25Z" fill="#754C36"/>
  <path d="M90 103V72" stroke="#5DAF8D" stroke-width="6" stroke-linecap="round"/>
  <path d="M89 82c-20-8-28-22-22-30 17 2 27 12 31 30Z" fill="#7DC4A1"/>
  <path d="M91 86c18-8 26-21 21-30-17 2-26 11-30 30Z" fill="#5DAF8D"/>
</svg>
''';
    case _PlantStage.young:
      return '''
<svg viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="90" cy="154" rx="56" ry="10" fill="#D8ECE4"/>
  <rect x="56" y="102" width="68" height="42" rx="14" fill="#C98E66"/>
  <path d="M66 102h48c-3 15-14 25-24 25s-21-10-24-25Z" fill="#754C36"/>
  <path d="M90 104V56" stroke="#3B9A78" stroke-width="7" stroke-linecap="round"/>
  <path d="M89 76c-26-10-38-27-31-40 24 3 38 17 45 40Z" fill="#67BB8F"/>
  <path d="M91 86c23-10 35-24 29-37-22 3-34 15-41 37Z" fill="#3B9A78"/>
  <path d="M89 62c-8-18-5-34 8-42 10 11 11 25-8 42Z" fill="#8AD0AA"/>
</svg>
''';
    case _PlantStage.thriving:
      return '''
<svg viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="90" cy="154" rx="58" ry="10" fill="#D8ECE4"/>
  <rect x="54" y="102" width="72" height="42" rx="14" fill="#C98E66"/>
  <path d="M65 102h50c-4 15-15 25-25 25s-21-10-25-25Z" fill="#754C36"/>
  <path d="M90 104V48" stroke="#248766" stroke-width="7" stroke-linecap="round"/>
  <path d="M90 74c-32-12-47-34-38-50 28 4 45 21 52 50Z" fill="#63B98D"/>
  <path d="M91 87c29-11 43-30 36-47-27 3-41 18-48 47Z" fill="#248766"/>
  <path d="M90 60c-10-22-7-40 9-49 14 12 14 29-9 49Z" fill="#96DAB5"/>
  <path d="M96 43c16-8 27-7 34 3-10 8-22 9-34-3Z" fill="#BEEACB"/>
</svg>
''';
    case _PlantStage.blooming:
      return '''
<svg viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="90" cy="154" rx="60" ry="10" fill="#D8ECE4"/>
  <rect x="52" y="102" width="76" height="42" rx="14" fill="#C98E66"/>
  <path d="M64 102h52c-4 15-16 25-26 25s-22-10-26-25Z" fill="#754C36"/>
  <path d="M90 104V44" stroke="#12785A" stroke-width="7" stroke-linecap="round"/>
  <path d="M89 74c-34-12-50-35-40-52 29 5 48 22 54 52Z" fill="#5EBA8A"/>
  <path d="M92 88c31-12 46-31 38-49-27 4-42 19-49 49Z" fill="#12785A"/>
  <path d="M90 57c-10-22-7-42 10-52 15 13 15 31-10 52Z" fill="#97DDB6"/>
  <circle cx="90" cy="39" r="13" fill="#FFE1A8"/>
  <circle cx="74" cy="42" r="10" fill="#FFD2D8"/>
  <circle cx="106" cy="42" r="10" fill="#FFD2D8"/>
  <circle cx="82" cy="27" r="10" fill="#FFEAC5"/>
  <circle cx="98" cy="27" r="10" fill="#FFEAC5"/>
</svg>
''';
  }
}
