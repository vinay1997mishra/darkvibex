/// Canonical Rocket chest frame rewards shared by the chest preview and Worker IDs.
const Map<String, Map<String, String>> rocketRewardFramesByGroup =
    <String, Map<String, String>>{
  '1-3': <String, String>{
    'id': 'rocket_frame_aurora',
    'name': 'Rocket Aurora',
    'style': 'frame_blue_magic_butterfly',
  },
  '4-6': <String, String>{
    'id': 'rocket_frame_neon_wings',
    'name': 'Rocket Neon Wings',
    'style': 'frame_neon_butterfly',
  },
  '7-9': <String, String>{
    'id': 'rocket_frame_golden_comet',
    'name': 'Rocket Golden Comet',
    'style': 'frame_golden_butterfly_queen',
  },
  '10-12': <String, String>{
    'id': 'rocket_frame_purple_nova',
    'name': 'Rocket Purple Nova',
    'style': 'frame_purple_dream_butterfly',
  },
};

Map<String, String> rocketRewardFrameForGroup(String? group) =>
    rocketRewardFramesByGroup[group] ?? rocketRewardFramesByGroup['1-3']!;
