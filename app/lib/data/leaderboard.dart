/// A single global-leaderboard row, built from real `profiles` data
/// (handle + numeric id + xp). Format shown in UI: `[USERNAME] - [ID]`.
class LeaderRow {
  final int rank;
  final String name;
  final String id;
  final int score;
  final bool you;
  final String initial;
  final String tier;
  const LeaderRow(this.rank, this.name, this.id, this.score, this.you,
      this.initial, this.tier);
}

/// Tier from total XP. Thresholds are intentionally simple for v1.
String tierForXp(int xp) {
  if (xp >= 2000) return 'S';
  if (xp >= 800) return 'A';
  if (xp >= 200) return 'B';
  return 'C';
}
