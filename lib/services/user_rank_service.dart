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
}
