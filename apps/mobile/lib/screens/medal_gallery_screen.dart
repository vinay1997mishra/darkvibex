import 'package:material_ui/material_ui.dart';

import '../widgets/level_medal.dart';
import '../widgets/vip_badge_video.dart';

class MedalGalleryScreen extends StatelessWidget {
  const MedalGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D1D),
        appBar: AppBar(
          title: const Text('Medal Collection'),
          backgroundColor: const Color(0xFF10152B),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFF9C8CFF),
            labelColor: const Color(0xFFE7E2FF),
            unselectedLabelColor: Colors.white54,
            tabs: [
              for (final tab in _tabs)
                Tab(icon: Icon(tab.icon), text: tab.label),
            ],
          ),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111A37), Color(0xFF17102D), Color(0xFF090D1D)],
            ),
          ),
          child: TabBarView(
            children: [
              for (final tab in _tabs) _MedalGrid(tab: tab),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTab {
  const _GalleryTab({
    required this.series,
    required this.label,
    required this.icon,
    required this.count,
    this.achievement,
  });

  final MedalSeries series;
  final String label;
  final IconData icon;
  final int count;

  /// Achievement slug for the achievement tab (one tab per medal).
  final String? achievement;
}

/// One tab per medal series. Achievement gets one tab per medal (6 tabs
/// of 10 levels each) so every tile is one medal at one level.
const List<_GalleryTab> _tabs = <_GalleryTab>[
  _GalleryTab(
    series: MedalSeries.vip,
    label: 'VIP 1–18',
    icon: Icons.workspace_premium_rounded,
    count: 18,
  ),
  _GalleryTab(
    series: MedalSeries.rocket,
    label: 'Rocket 1–18',
    icon: Icons.rocket_launch_rounded,
    count: 18,
  ),
  _GalleryTab(
    series: MedalSeries.wealth,
    label: 'Wealth 1–18',
    icon: Icons.diamond_rounded,
    count: 18,
  ),
  _GalleryTab(
    series: MedalSeries.fanclub,
    label: 'Fan Club 1–18',
    icon: Icons.favorite_rounded,
    count: 18,
  ),
  _GalleryTab(
    series: MedalSeries.achievement,
    label: 'Active Star',
    icon: Icons.emoji_events_rounded,
    count: 10,
    achievement: 'active',
  ),
  _GalleryTab(
    series: MedalSeries.achievement,
    label: 'Wealth Medal',
    icon: Icons.emoji_events_rounded,
    count: 10,
    achievement: 'wealth',
  ),
  _GalleryTab(
    series: MedalSeries.achievement,
    label: 'Live Stream',
    icon: Icons.emoji_events_rounded,
    count: 10,
    achievement: 'live',
  ),
  _GalleryTab(
    series: MedalSeries.achievement,
    label: 'Live Star',
    icon: Icons.emoji_events_rounded,
    count: 10,
    achievement: 'livestar',
  ),
  _GalleryTab(
    series: MedalSeries.achievement,
    label: 'Top Gifter',
    icon: Icons.emoji_events_rounded,
    count: 10,
    achievement: 'topgifter',
  ),
  _GalleryTab(
    series: MedalSeries.achievement,
    label: 'Fan Power',
    icon: Icons.emoji_events_rounded,
    count: 10,
    achievement: 'fanpower',
  ),
  _GalleryTab(
    series: MedalSeries.family,
    label: 'Family 1–10',
    icon: Icons.shield_rounded,
    count: 10,
  ),
  _GalleryTab(
    series: MedalSeries.charm,
    label: 'Charm 1–18',
    icon: Icons.mic_rounded,
    count: 18,
  ),
  _GalleryTab(
    series: MedalSeries.noble,
    label: 'Noble 1–10',
    icon: Icons.military_tech_rounded,
    count: 10,
  ),
  _GalleryTab(
    series: MedalSeries.room,
    label: 'Room Top 3',
    icon: Icons.home_rounded,
    count: 3,
  ),
  _GalleryTab(
    series: MedalSeries.event,
    label: 'Event',
    icon: Icons.celebration_rounded,
    count: 1,
  ),
];

class _MedalGrid extends StatelessWidget {
  const _MedalGrid({required this.tab});

  final _GalleryTab tab;

  @override
  Widget build(BuildContext context) {
    final isVip = tab.series == MedalSeries.vip;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      itemCount: tab.count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: .79,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final level = index + 1;
        final Widget tile = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xAA11172C),
            border: Border.all(
              color: _tabBorderColor(tab.series).withValues(alpha: .24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 9, 4, 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: LevelMedal(
                    series: tab.series,
                    level: level,
                    size: 94,
                    achievement: tab.achievement,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tileTitle(tab, level),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _tileSubtitle(tab, level),
                style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _isPermanent(tab.series)
                      ? const Color(0xFF2E7D32).withValues(alpha: .35)
                      : const Color(0xFFB26A00).withValues(alpha: .35),
                ),
                child: Text(
                  _validityText(tab, level),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
        // VIP medals are tap-to-play: tapping a VIP tile opens a dialog
        // that plays that level's badge video once. NO autoplay in the
        // grid — 18 videos must never play at once. Other medals have
        // no badge video, so they are not tappable.
        if (!isVip) return tile;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showVipBadge(context, level),
          child: tile,
        );
      },
    );
  }

  /// Plays one level's badge video in a dialog. The video plays once
  /// and falls back to the LevelMedal SVG on completion/error.
  void _showVipBadge(BuildContext context, int level) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF11172C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VipBadgeVideo.forVipLevel(level: level, size: 280),
              const SizedBox(height: 12),
              Text(
                'VIP $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _vipTier(level),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tileTitle(_GalleryTab tab, int level) {
    switch (tab.series) {
      case MedalSeries.vip:
        return 'VIP $level';
      case MedalSeries.rocket:
        return 'Rocket $level';
      case MedalSeries.wealth:
        return 'Wealth $level';
      case MedalSeries.fanclub:
        return 'Fan Club $level';
      case MedalSeries.achievement:
        return '${tab.label} $level';
      case MedalSeries.family:
        return 'Family $level';
      case MedalSeries.charm:
        return 'Charm $level';
      case MedalSeries.noble:
        return 'Noble $level';
      case MedalSeries.room:
        return 'Top $level';
      case MedalSeries.event:
        return 'Event';
    }
  }

  String _tileSubtitle(_GalleryTab tab, int level) {
    switch (tab.series) {
      case MedalSeries.vip:
        return _vipTier(level);
      case MedalSeries.rocket:
        return _rocketTier(level);
      case MedalSeries.wealth:
        return _wealthTier(level);
      case MedalSeries.fanclub:
        return _fanclubTier(level);
      case MedalSeries.achievement:
        return 'Lv. $level';
      case MedalSeries.family:
        return _familyTier(level);
      case MedalSeries.charm:
        return _charmTier(level);
      case MedalSeries.noble:
        return _nobleTier(level);
      case MedalSeries.room:
        return level == 1 ? 'Gold' : level == 2 ? 'Silver' : 'Bronze';
      case MedalSeries.event:
        return 'Limited time';
    }
  }

  /// Permanent (green badge) vs days-based (amber badge).
  /// VIP follows the VIP expiry rule (30 days VIP1-15, 60 days VIP16-18).
  bool _isPermanent(MedalSeries series) => switch (series) {
        MedalSeries.wealth ||
        MedalSeries.achievement ||
        MedalSeries.event ||
        MedalSeries.rocket => true,
        _ => false,
      };

  String _validityText(_GalleryTab tab, int level) {
    switch (tab.series) {
      case MedalSeries.vip:
        // VIP1-15 = 30 days, VIP16-18 = 60 days (existing VIP rule).
        return level >= 16 ? '60 days' : '30 days';
      case MedalSeries.rocket:
      case MedalSeries.wealth:
      case MedalSeries.achievement:
      case MedalSeries.event:
        return 'Permanent';
      case MedalSeries.room:
        return '7 days';
      case MedalSeries.fanclub:
      case MedalSeries.family:
      case MedalSeries.charm:
      case MedalSeries.noble:
        return '30 days';
    }
  }

  Color _tabBorderColor(MedalSeries series) => switch (series) {
        MedalSeries.vip => const Color(0xFFB6A2FF),
        MedalSeries.rocket => const Color(0xFF78D9FF),
        MedalSeries.wealth => const Color(0xFFFFD34D),
        MedalSeries.fanclub => const Color(0xFFFF7EB6),
        MedalSeries.achievement => const Color(0xFFFFC94D),
        MedalSeries.family => const Color(0xFF7EA8FF),
        MedalSeries.charm => const Color(0xFFFF9ECF),
        MedalSeries.noble => const Color(0xFFB678FF),
        MedalSeries.room => const Color(0xFFFFD34D),
        MedalSeries.event => const Color(0xFF7CFFB2),
      };

  String _vipTier(int level) => switch (level) {
        1 => 'First Light',
        2 => 'Amethyst',
        3 => 'Azure Crest',
        4 => 'Phoenix',
        5 => 'Emerald Elite',
        6 => 'Royal Wings',
        7 => 'Sun Crown',
        8 => 'Sapphire Guard',
        9 => 'Rose Jewel',
        10 => 'Platinum',
        11 => 'Fire Regent',
        12 => 'Glacier',
        13 => 'Verdant Crown',
        14 => 'Mystic',
        15 => 'Celestial',
        16 => 'Oceanic',
        17 => 'Crimson Throne',
        _ => 'DarkVibeX Apex',
      };

  String _rocketTier(int level) => switch (level) {
        1 => 'Launch',
        2 => 'Blaze',
        3 => 'Comet',
        4 => 'Solar',
        5 => 'Nova',
        6 => 'Gold Rush',
        7 => 'Tidal',
        8 => 'Rose Jet',
        9 => 'Phantom',
        10 => 'Inferno',
        11 => 'Stellar',
        12 => 'Orbit King',
        13 => 'Star Forge',
        14 => 'Nebula',
        15 => 'Cosmic',
        16 => 'Galactic',
        17 => 'Supernova',
        _ => 'Rocket Apex',
      };

  String _wealthTier(int level) => switch (level) {
        1 => 'Bronze',
        2 => 'Silver',
        3 => 'Gold',
        4 => 'Purple',
        5 => 'Ruby',
        6 => 'Sapphire',
        7 => 'Emerald',
        8 => 'Rose',
        9 => 'Amber',
        10 => 'Cyan',
        11 => 'Gold Ruby',
        12 => 'Gold Sapphire',
        13 => 'Gold Purple',
        14 => 'Gold Emerald',
        15 => 'Platinum',
        16 => 'Diamond',
        17 => 'Rainbow',
        _ => 'Royal',
      };

  String _fanclubTier(int level) => switch (level) {
        1 => 'New Fan',
        2 => 'Supporter',
        3 => 'Loyal Fan',
        4 => 'Super Fan',
        5 => 'Devoted',
        6 => 'Heart',
        7 => 'Star Fan',
        8 => 'Diamond Fan',
        9 => 'Royal Fan',
        10 => 'Elite Fan',
        11 => 'Legend Fan',
        12 => 'Mythic Fan',
        13 => 'Eternal Fan',
        14 => 'Guardian',
        15 => 'Champion',
        16 => 'Apex Fan',
        17 => 'Immortal Fan',
        _ => 'Soul Fan',
      };

  String _familyTier(int level) => switch (level) {
        1 => 'Member',
        2 => 'Bronze',
        3 => 'Silver',
        4 => 'Gold',
        5 => 'Elite',
        6 => 'Royal',
        7 => 'Noble',
        8 => 'Legend',
        9 => 'Mythic',
        _ => 'Supreme',
      };

  String _charmTier(int level) => switch (level) {
        1 => 'New Voice',
        2 => 'Sweet Voice',
        3 => 'Melody',
        4 => 'Star Voice',
        5 => 'Golden Voice',
        6 => 'Charming',
        7 => 'Enchanter',
        8 => 'Diva',
        9 => 'Siren',
        10 => 'Idol',
        11 => 'Superstar',
        12 => 'Legend',
        13 => 'Icon',
        14 => 'Queen',
        15 => 'Goddess',
        16 => 'Celestial',
        17 => 'Eternal',
        _ => 'Supreme Charm',
      };

  String _nobleTier(int level) => switch (level) {
        1 => 'Baron',
        2 => 'Viscount',
        3 => 'Count',
        4 => 'Marquess',
        5 => 'Duke',
        6 => 'Grand Duke',
        7 => 'Prince',
        8 => 'Crown Prince',
        9 => 'King',
        _ => 'Emperor',
      };
}
