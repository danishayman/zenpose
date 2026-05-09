import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/badge_definition.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/profile_challenge_models.dart';
import 'package:zenpose/models/user_rank.dart';
import 'package:zenpose/models/user_stats.dart';
import 'package:zenpose/screens/all_challenges_screen.dart';
import 'package:zenpose/screens/profile_screen.dart';
import 'package:zenpose/services/profile_challenge_service.dart';
import 'package:zenpose/theme/zen_theme.dart';

void main() {
  final stats = UserStats(
    currentStreak: 4,
    longestStreak: 8,
    totalXp: 920,
    lastActiveDate: DateTime(2026, 4, 10),
  );
  final results = <PoseResult>[
    PoseResult(
      poseName: 'Tree',
      bestScore: 88,
      holdDuration: 60,
      completed: true,
      timestamp: DateTime(2026, 4, 10, 8, 0),
    ),
  ];
  const definitions = <BadgeDefinition>[
    BadgeDefinition(
      id: 'first_completion',
      name: 'First Breath',
      description: 'Complete your first session',
      criteriaType: 'completed_sessions',
      criteriaValue: 1,
    ),
  ];

  testWidgets(
    'profile shows challenges below achievements and opens all screen',
    (tester) async {
      _setLargeSurface(tester);
      final fakeService = _FakeProfileChallengeService(
        snapshots: [
          _buildSnapshot(
            challengeId: 'sessions_20',
            title: 'April 20 Sessions Challenge',
            metricType: ChallengeMetricType.sessions,
            status: ChallengeLifecycleStatus.notJoined,
            buttonLabel: 'Join',
            currentValue: 4,
            targetValue: 20,
          ),
        ],
      );

      await tester.pumpWidget(
        _app(
          ProfileScreen(
            loadUserStats: () async => stats,
            loadBadgeCount: () async => 1,
            loadAllResults: () async => results,
            loadBadgeDefinitions: () async => definitions,
            loadUnlockedBadges: () async => const [],
            loadChallenges: () async => fakeService.snapshots,
            challengeService: fakeService,
            nowBuilder: () => DateTime(2026, 4, 20, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final achievements = find.text('Achievements');
      final challenges = find.text('Challenges');
      expect(achievements, findsOneWidget);
      expect(challenges, findsOneWidget);
      expect(
        tester.getTopLeft(challenges).dy,
        greaterThan(tester.getTopLeft(achievements).dy),
      );

      await tester.tap(find.byKey(const Key('profile-challenges-view-all')));
      await tester.pumpAndSettle();
      expect(find.byType(AllChallengesScreen), findsOneWidget);
      expect(find.byKey(const Key('all-challenges-grid')), findsOneWidget);
    },
  );

  testWidgets(
    'all challenges CTA transitions Join->Joined and Claim->Completed',
    (tester) async {
      _setLargeSurface(tester);
      final fakeService = _FakeProfileChallengeService(
        snapshots: [
          _buildSnapshot(
            challengeId: 'sessions_20',
            title: 'April 20 Sessions Challenge',
            metricType: ChallengeMetricType.sessions,
            status: ChallengeLifecycleStatus.notJoined,
            buttonLabel: 'Join',
            currentValue: 4,
            targetValue: 20,
          ),
          _buildSnapshot(
            challengeId: 'score_90_x5',
            title: 'April 90+ Score Challenge',
            metricType: ChallengeMetricType.scoreCount,
            status: ChallengeLifecycleStatus.claimable,
            buttonLabel: 'Claim',
            currentValue: 5,
            targetValue: 5,
          ),
        ],
      );

      await tester.pumpWidget(
        _app(
          AllChallengesScreen(
            monthKey: '2026-04',
            challengeService: fakeService,
            nowBuilder: () => DateTime(2026, 4, 20, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Claim'), findsOneWidget);

      await tester.tap(find.byKey(const Key('challenge-action-sessions_20')));
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsOneWidget);

      await tester.tap(find.byKey(const Key('challenge-action-score_90_x5')));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
    },
  );

  testWidgets('claim shows rank-up popup when rank tier increases', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final fakeService = _FakeProfileChallengeService(
      rankUpOnClaim: true,
      snapshots: [
        _buildSnapshot(
          challengeId: 'score_90_x5',
          title: 'April 90+ Score Challenge',
          metricType: ChallengeMetricType.scoreCount,
          status: ChallengeLifecycleStatus.claimable,
          buttonLabel: 'Claim',
          currentValue: 5,
          targetValue: 5,
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        AllChallengesScreen(
          monthKey: '2026-04',
          challengeService: fakeService,
          nowBuilder: () => DateTime(2026, 4, 20, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('challenge-action-score_90_x5')));
    await tester.pumpAndSettle();

    expect(find.text('Rank Up!'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('claim does not show rank-up popup without rank transition', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final fakeService = _FakeProfileChallengeService(
      rankUpOnClaim: false,
      snapshots: [
        _buildSnapshot(
          challengeId: 'score_90_x5',
          title: 'April 90+ Score Challenge',
          metricType: ChallengeMetricType.scoreCount,
          status: ChallengeLifecycleStatus.claimable,
          buttonLabel: 'Claim',
          currentValue: 5,
          targetValue: 5,
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        AllChallengesScreen(
          monthKey: '2026-04',
          challengeService: fakeService,
          nowBuilder: () => DateTime(2026, 4, 20, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('challenge-action-score_90_x5')));
    await tester.pumpAndSettle();

    expect(find.text('Rank Up!'), findsNothing);
    expect(find.text('Completed'), findsOneWidget);
  });
}

class _FakeProfileChallengeService extends ProfileChallengeService {
  List<ChallengeProgressSnapshot> snapshots;
  final bool rankUpOnClaim;

  _FakeProfileChallengeService({
    required this.snapshots,
    this.rankUpOnClaim = false,
  });

  @override
  Future<List<ChallengeProgressSnapshot>> loadMonthlyChallenges({
    DateTime? now,
    String? monthKey,
  }) async {
    return snapshots;
  }

  @override
  Future<void> joinChallenge({
    required String monthKey,
    required String challengeId,
    DateTime? now,
  }) async {
    snapshots = snapshots
        .map(
          (item) => item.definition.challengeId == challengeId
              ? _copySnapshot(
                  item,
                  status: ChallengeLifecycleStatus.joined,
                  buttonLabel: 'Joined',
                  isJoined: true,
                )
              : item,
        )
        .toList(growable: false);
  }

  @override
  Future<ChallengeClaimResult> claimChallengeReward({
    required String monthKey,
    required String challengeId,
    DateTime? now,
  }) async {
    snapshots = snapshots
        .map(
          (item) => item.definition.challengeId == challengeId
              ? _copySnapshot(
                  item,
                  status: ChallengeLifecycleStatus.completed,
                  buttonLabel: 'Completed',
                  isJoined: true,
                  rewardBadgeLabel: 'Claimed Badge',
                )
              : item,
        )
        .toList(growable: false);
    return ChallengeClaimResult(
      applied: true,
      xpGranted: 120,
      xpBefore: 900,
      xpAfter: rankUpOnClaim ? 1020 : 980,
      rankBefore: UserRankTier.bronze,
      rankAfter: rankUpOnClaim ? UserRankTier.silver : UserRankTier.bronze,
      didRankUp: rankUpOnClaim,
      badgeLabel: 'Claimed Badge',
      message: 'Claimed',
    );
  }
}

ChallengeProgressSnapshot _buildSnapshot({
  required String challengeId,
  required String title,
  required ChallengeMetricType metricType,
  required ChallengeLifecycleStatus status,
  required String buttonLabel,
  required double currentValue,
  required double targetValue,
}) {
  return ChallengeProgressSnapshot(
    definition: ProfileChallengeDefinition(
      challengeId: challengeId,
      title: title,
      description: 'Test description',
      metricType: metricType,
      targetValue: targetValue,
      scoreThreshold: metricType == ChallengeMetricType.scoreCount ? 90 : null,
      rewardXp: 120,
      rewardBadgeLabel: 'Test Badge',
    ),
    monthKey: '2026-04',
    status: status,
    isJoined: status != ChallengeLifecycleStatus.notJoined,
    currentValue: currentValue,
    targetValue: targetValue,
    progressRatio: targetValue == 0
        ? 1
        : (currentValue / targetValue).clamp(0, 1),
    progressLabel: '$currentValue / $targetValue',
    periodLabel: 'April 1 to April 30, 2026',
    buttonLabel: buttonLabel,
    rewardBadgeLabel: null,
    rewardXp: 120,
  );
}

ChallengeProgressSnapshot _copySnapshot(
  ChallengeProgressSnapshot source, {
  required ChallengeLifecycleStatus status,
  required String buttonLabel,
  required bool isJoined,
  String? rewardBadgeLabel,
}) {
  return ChallengeProgressSnapshot(
    definition: source.definition,
    monthKey: source.monthKey,
    status: status,
    isJoined: isJoined,
    currentValue: source.currentValue,
    targetValue: source.targetValue,
    progressRatio: source.progressRatio,
    progressLabel: source.progressLabel,
    periodLabel: source.periodLabel,
    buttonLabel: buttonLabel,
    rewardBadgeLabel: rewardBadgeLabel ?? source.rewardBadgeLabel,
    rewardXp: source.rewardXp,
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ZenTheme.build(),
    home: Scaffold(body: child),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
