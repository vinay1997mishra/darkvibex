/// Stable identifiers and labels for the 100 animated Rocket Reward frames.
/// The four groups correspond to the Rocket reward pools (25 frames per group).
const Map<String, int> _rocketGroupIndex = <String, int>{
  '1-3': 1,
  '4-6': 2,
  '7-9': 3,
  '10-12': 4,
};

const Map<int, String> _rocketGroupLabel = <int, String>{
  1: 'Rocket Levels 1–3',
  2: 'Rocket Levels 4–6',
  3: 'Rocket Levels 7–9',
  4: 'Rocket Levels 10–12',
};

const Map<int, int> _rocketGroupDays = <int, int>{
  1: 1,
  2: 5,
  3: 7,
  4: 10,
};

String rocketFrameIdForSlot(String rewardGroup, int slot) {
  final groupIndex = _rocketGroupIndex[rewardGroup];
  if (groupIndex == null || slot < 1 || slot > 25) {
    throw ArgumentError('Unknown Rocket frame group or slot.');
  }
  return 'rocket_frame_g${groupIndex}_${slot.toString().padLeft(2, '0')}';
}

bool isRocketRewardFrameId(String? id) =>
    id != null &&
    RegExp(r'^rocket_frame_g[1-4]_(?:0[1-9]|1[0-9]|2[0-5])$')
        .hasMatch(id);

int rocketFrameGroupIndex(String? id) {
  if (!isRocketRewardFrameId(id)) return 0;
  return int.tryParse(id!.substring('rocket_frame_g'.length, 'rocket_frame_g'.length + 1)) ?? 0;
}

int rocketFrameVariant(String? id) {
  if (!isRocketRewardFrameId(id)) return 0;
  return int.tryParse(id!.substring(id.length - 2)) ?? 0;
}

String rocketFrameRewardGroup(String? id) {
  return switch (rocketFrameGroupIndex(id)) {
    1 => '1-3',
    2 => '4-6',
    3 => '7-9',
    4 => '10-12',
    _ => '',
  };
}

int rocketFrameDurationDays(String? id) =>
    _rocketGroupDays[rocketFrameGroupIndex(id)] ?? 0;

String rocketFrameDisplayName(String? id) {
  final group = rocketFrameGroupIndex(id);
  final variant = rocketFrameVariant(id);
  if (group == 0 || variant == 0) return 'Rocket Animated Frame';
  return '${_rocketGroupLabel[group]} • Frame ${variant.toString().padLeft(2, '0')}';
}

List<String> rocketFrameSampleIds(String rewardGroup) =>
    <String>[
      rocketFrameIdForSlot(rewardGroup, 1),
      rocketFrameIdForSlot(rewardGroup, 13),
      rocketFrameIdForSlot(rewardGroup, 25),
    ];

const List<List<String>> _rocketArtworkStylesByGroup = <List<String>>[
  <String>['frame_golden_crown', 'frame_pink_heart', 'frame_blue_butterfly', 'frame_purple_star', 'frame_golden_flower'],
  <String>['frame_blue_angel_crown', 'frame_purple_butterfly', 'frame_blue_magic_butterfly', 'frame_golden_butterfly_queen', 'frame_royal_love'],
  <String>['frame_red_black_royal_wings', 'frame_red_rose', 'frame_purple_dream_butterfly', 'frame_neon_butterfly', 'frame_blue_magic_butterfly'],
  <String>['frame_golden_crown', 'frame_blue_angel_crown', 'frame_red_black_royal_wings', 'frame_purple_dream_butterfly', 'frame_neon_butterfly'],
];

/// Reuses the app's existing high-detail transparent frame artwork, then adds
/// Rocket-tier-specific ornaments and motion so reward frames match the premium
/// style already used on profile and room-seat avatars.
String rocketFrameArtworkStyleId(String? id) {
  final group = rocketFrameGroupIndex(id);
  final variant = rocketFrameVariant(id);
  if (group == 0 || variant == 0) return 'frame_golden_crown';
  final styles = _rocketArtworkStylesByGroup[group - 1];
  return styles[(variant - 1) % styles.length];
}
