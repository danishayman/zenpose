enum UserRankTier { bronze, silver, gold, emerald, diamond }

extension UserRankTierX on UserRankTier {
  String get label {
    switch (this) {
      case UserRankTier.bronze:
        return 'Bronze';
      case UserRankTier.silver:
        return 'Silver';
      case UserRankTier.gold:
        return 'Gold';
      case UserRankTier.emerald:
        return 'Emerald';
      case UserRankTier.diamond:
        return 'Diamond';
    }
  }

  String get badgeAssetPath {
    switch (this) {
      case UserRankTier.bronze:
        return 'assets/ranks/bronze.png';
      case UserRankTier.silver:
        return 'assets/ranks/silver.png';
      case UserRankTier.gold:
        return 'assets/ranks/gold.png';
      case UserRankTier.emerald:
        return 'assets/ranks/emerald.png';
      case UserRankTier.diamond:
        return 'assets/ranks/diamond.png';
    }
  }

  int get order {
    switch (this) {
      case UserRankTier.bronze:
        return 0;
      case UserRankTier.silver:
        return 1;
      case UserRankTier.gold:
        return 2;
      case UserRankTier.emerald:
        return 3;
      case UserRankTier.diamond:
        return 4;
    }
  }
}
