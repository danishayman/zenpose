import '../models/user_rank.dart';

class UserRankService {
  static const int bronzeMaxXp = 999;
  static const int silverMaxXp = 2999;
  static const int goldMaxXp = 6999;
  static const int emeraldMaxXp = 11999;

  static UserRankTier rankForXp(int totalXp) {
    if (totalXp <= bronzeMaxXp) {
      return UserRankTier.bronze;
    }
    if (totalXp <= silverMaxXp) {
      return UserRankTier.silver;
    }
    if (totalXp <= goldMaxXp) {
      return UserRankTier.gold;
    }
    if (totalXp <= emeraldMaxXp) {
      return UserRankTier.emerald;
    }
    return UserRankTier.diamond;
  }

  static bool didRankUp({
    required UserRankTier previousRank,
    required UserRankTier currentRank,
  }) {
    return currentRank.order > previousRank.order;
  }

  static bool didRankDown({
    required UserRankTier previousRank,
    required UserRankTier currentRank,
  }) {
    return currentRank.order < previousRank.order;
  }

  static double penaltyMultiplierForRank(UserRankTier rank) {
    switch (rank) {
      case UserRankTier.bronze:
        return 1.0;
      case UserRankTier.silver:
        return 1.2;
      case UserRankTier.gold:
        return 1.5;
      case UserRankTier.emerald:
        return 1.8;
      case UserRankTier.diamond:
        return 2.2;
    }
  }
}
