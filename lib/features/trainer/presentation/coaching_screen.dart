import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/trainer_relation.dart';
import '../../../data/services/trainer_api_service.dart';

/// ЭТАП 17: реальная (не мок-каталог) связь тренер-клиент, работающая
/// через backend trainer_clients — приглашения по email, подтверждение
/// клиентом, Coach Plan/Daily Target/Assigned Meals/Coach Comments на
/// стороне клиента и список подключённых клиентов на стороне тренера.
/// Отдельно от TrainerScreen (мок-каталог тренеров с карточками/чатом) —
/// те тренеры не привязаны к реальным аккаунтам, с ними нечего подключать.
class CoachingScreen extends StatelessWidget {
  const CoachingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Тренерская программа'),
          leading: const BackButton(),
          bottom: const TabBar(tabs: [Tab(text: 'Мой тренер'), Tab(text: 'Мои клиенты')]),
        ),
        body: const SafeArea(
          child: TabBarView(children: [_MyCoachTab(), _MyClientsTab()]),
        ),
      ),
    );
  }
}

class _MyCoachTab extends ConsumerWidget {
  const _MyCoachTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(myInvitesProvider);
    final trainersAsync = ref.watch(myTrainersProvider);
    final planAsync = ref.watch(myCoachPlanProvider);
    final assignmentsAsync = ref.watch(myAssignmentsProvider);
    final commentsAsync = ref.watch(myCommentsProvider);

    Future<void> refreshAll() async {
      ref.invalidate(myInvitesProvider);
      ref.invalidate(myTrainersProvider);
      ref.invalidate(myCoachPlanProvider);
      ref.invalidate(myAssignmentsProvider);
      ref.invalidate(myCommentsProvider);
    }

    final anyLoading = [invitesAsync, trainersAsync, planAsync, assignmentsAsync, commentsAsync].any((a) => a.isLoading);
    final anyError = [invitesAsync, trainersAsync, planAsync, assignmentsAsync, commentsAsync].firstWhere((a) => a.hasError, orElse: () => const AsyncValue.data(null));

    if (anyLoading && !anyError.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    if (anyError.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              anyError.error is ApiException ? (anyError.error as ApiException).message : 'Не удалось загрузить данные',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: refreshAll, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final invites = invitesAsync.value ?? const [];
    final trainers = trainersAsync.value ?? const [];
    final plan = planAsync.value;
    final assignments = assignmentsAsync.value ?? const [];
    final comments = commentsAsync.value ?? const [];

    final isEmpty = invites.isEmpty && trainers.isEmpty && plan == null && assignments.isEmpty && comments.isEmpty;
    if (isEmpty) {
      return const EmptyState(emoji: '🤝', title: 'Пока нет тренера', subtitle: 'Попроси тренера отправить тебе приглашение по email');
    }

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (invites.isNotEmpty) ...[
            Text('Приглашения', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final invite in invites) ...[
              _InviteCard(invite: invite, onResponded: refreshAll),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (trainers.isNotEmpty) ...[
            Text('Мои тренеры', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final t in trainers) ...[
              AppCard(child: Text(t.counterpart?.name ?? t.trainerId, style: Theme.of(context).textTheme.bodyLarge)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (plan != null) ...[
            Text('Coach Plan · Daily Target', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              color: AppColors.ink900,
              shadow: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (plan.title != null && plan.title!.isNotEmpty)
                    Text(plan.title!, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (plan.calorieTarget != null) '${plan.calorieTarget} ккал',
                      if (plan.proteinTarget != null) 'Белок ${plan.proteinTarget} г',
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (plan.notes != null && plan.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(plan.notes!, style: const TextStyle(color: Colors.white70)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (assignments.isNotEmpty) ...[
            Text('Assigned Meals', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final a in assignments) ...[
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, color: AppColors.green600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          if (a.notes != null && a.notes!.isNotEmpty) Text(a.notes!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (a.recipeId != null)
                      TextButton(onPressed: () => context.push('/recipes/${a.recipeId}'), child: const Text('Рецепт')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (comments.isNotEmpty) ...[
            Text('Coach Comments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final c in comments) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.message, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(DateFormat('d MMMM, HH:mm', 'ru').format(c.createdAt.toLocal()), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.invite, required this.onResponded});
  final TrainerRelation invite;
  final Future<void> Function() onResponded;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _respond(bool approve) async {
    setState(() => _busy = true);
    try {
      await ref.read(trainerApiServiceProvider).respondToInvite(widget.invite.id, approve);
      await widget.onResponded();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.invite.counterpart?.name ?? 'Тренер'} приглашает вас в клиенты',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (_busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            IconButton(onPressed: () => _respond(false), icon: const Icon(Icons.close_rounded, color: AppColors.error)),
            IconButton(onPressed: () => _respond(true), icon: const Icon(Icons.check_rounded, color: AppColors.green600)),
          ],
        ],
      ),
    );
  }
}

class _MyClientsTab extends ConsumerStatefulWidget {
  const _MyClientsTab();

  @override
  ConsumerState<_MyClientsTab> createState() => _MyClientsTabState();
}

class _MyClientsTabState extends ConsumerState<_MyClientsTab> {
  final _email = TextEditingController();
  bool _inviting = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _email.text.trim();
    if (email.isEmpty || _inviting) return;
    setState(() => _inviting = true);
    try {
      await ref.read(trainerApiServiceProvider).inviteClient(email);
      _email.clear();
      ref.invalidate(myClientsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Приглашение отправлено')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(myClientsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myClientsProvider),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Пригласить клиента', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'email клиента'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _inviting ? null : _invite,
                  child: _inviting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Пригласить'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Мои клиенты', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          clientsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator())),
            error: (err, st) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(err is ApiException ? err.message : 'Не удалось загрузить клиентов', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(onPressed: () => ref.invalidate(myClientsProvider), child: const Text('Повторить')),
                ],
              ),
            ),
            data: (clients) => clients.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: EmptyState(emoji: '👥', title: 'Пока нет клиентов', subtitle: 'Пригласи клиента по email — доступ откроется после его подтверждения'),
                  )
                : Column(
                    children: [
                      for (final c in clients) ...[
                        AppCard(
                          onTap: () => context.push('/coaching/clients/${c.clientId}', extra: c.counterpart?.name),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.counterpart?.name ?? c.clientId, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                    if (c.counterpart != null) Text(c.counterpart!.email, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
