import 'package:flutter/material.dart';

import '../widgets/level_medal.dart';
import '../widgets/vip_badge_video.dart';

class MedalGalleryScreen extends StatelessWidget {
  const MedalGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D1D),
        appBar: AppBar(
          title: const Text('Medal Collection'),
          backgroundColor: const Color(0xFF10152B),
          bottom: const TabBar(
            indicatorColor: Color(0xFF9C8CFF),
            labelColor: Color(0xFFE7E2FF),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.workspace_premium_rounded), text: 'VIP 1–18'),
              Tab(icon: Icon(Icons.rocket_launch_rounded), text: 'Rocket 1–18'),
            ],
          ),
        ),
        body: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111A37), Color(0xFF17102D), Color(0xFF090D1D)],
            ),
          ),
          child: TabBarView(
            children: [
              _MedalGrid(series: MedalSeries.vip, count: 18),
              _MedalGrid(series: MedalSeries.rocket, count: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedalGrid extends StatelessWidget {
  const _MedalGrid({required this.series, required this.count});

  final MedalSeries series;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isVip = series == MedalSeries.vip;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      itemCount: count,
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
              color: (isVip ? const Color(0xFFB6A2FF) : const Color(0xFF78D9FF))
                  .withValues(alpha: .24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 9, 4, 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: LevelMedal(
                    series: series,
                    level: level,
                    size: 94,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isVip ? 'VIP $level' : 'Rocket $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isVip ? _vipTier(level) : _rocketTier(level),
                style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        );
        // VIP medals are tap-to-play: tapping a VIP tile opens a dialog
        // that plays that level's badge video once. NO autoplay in the
        // grid — 18 videos must never play at once. Rocket medals have
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
}
