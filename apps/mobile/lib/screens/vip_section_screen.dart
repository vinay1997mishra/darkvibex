// DarkVibeX — VIP Section Screen (black + gold + purple, no brown)
// Modelled on the reference SVIP screen the user uploaded (dark + gold,
// ornate gold, level tabs, animal emblem on a pedestal, progress bar,
// "VIP Identity" grid, "Exclusive Privileges" grid, recharge banner,
// optional WIN banner). Adapted to DarkVibeX: VIP1-18, DarkVibeX animals,
// DarkVibeX privileges from VipPolicy. NO brown anywhere: backgrounds are
// black / near-black, gold is the main accent and purple is the second
// accent (emblem gradients, progress fill, selected-tab glow, unlocked
// card highlights). No brown anywhere.
//
// VIP frame style (chosen by Vinay 2026-11-18, 3rd of 3 pics): super
// premium golden dragon frame with purple fire glow. The dragon-frame
// style was NOT applied to the VIP section (Vinay, 2026-11-20, "Nhi") —
// the per-level animal frames stay as they are. The emblem shows the
// level's real animal frame still from R2 (frames/vip<N>-<animal>-
// transparent.png) inside a gold-ring + purple-glow circle.
// VIP tags: real golden tag images per level (VIP1-18, animal +
// "VIP<n>" on a transparent background) live on R2 under vip-tags/ and
// are shown with the VipTagImage widget (R2-based, works for all 18).
// Gift Banner / gift ribbon EXISTS in the app now (gift_ribbon_banner.dart
// + R2 gift-ribbons/, wired in room_screen.dart) — it is shown as an
// unlocked reward, not "coming soon".
// "Exp 110% Speed up" EXISTS (worker expBoostForLevel: 1.1x at VIP1,
// 1.2x at VIP5, 1.4x at VIP11, 1.5x at VIP16). "More Profile Background"
// has no matching entry and is NOT shown.
// Coins bonus is the real purchase bonus from the VIP policy: +5% at
// VIP5, +10% at VIP11, +20% at VIP16 (coinsBonusForPurchase).
import 'package:flutter/material.dart';

import '../vip/vip_policy.dart';
import '../vip/vip_visual_assets.dart';
import '../widgets/vip_tag_image.dart';

/// One animal (or crown) emblem per VIP level, from the DarkVibeX
/// vehicle-entry animal list. VIP1-4 have no animal vehicle, so they use
/// a gold crown. The emoji is only the fallback label — the emblem shows
/// the level's real animal frame still from R2.
class VipAnimal {
  const VipAnimal({
    required this.level,
    required this.name,
    required this.emoji,
    required this.category,
    required this.rarity,
  });

  final int level;
  final String name;
  final String emoji;
  final String category;
  final String rarity;
}

const List<VipAnimal> vipAnimals = <VipAnimal>[
  VipAnimal(level: 1, name: 'Crown', emoji: '👑', category: 'Emblem', rarity: 'Rare'),
  VipAnimal(level: 2, name: 'Crown', emoji: '👑', category: 'Emblem', rarity: 'Rare'),
  VipAnimal(level: 3, name: 'Crown', emoji: '👑', category: 'Emblem', rarity: 'Rare'),
  VipAnimal(level: 4, name: 'Crown', emoji: '👑', category: 'Emblem', rarity: 'Rare'),
  VipAnimal(level: 5, name: 'Deer', emoji: '🦌', category: 'Land', rarity: 'Rare'),
  VipAnimal(level: 6, name: 'Wolf', emoji: '🐺', category: 'Land', rarity: 'Rare'),
  VipAnimal(level: 7, name: 'Eagle', emoji: '🦅', category: 'Air', rarity: 'Rare'),
  VipAnimal(level: 8, name: 'Panther', emoji: '🐆', category: 'Land', rarity: 'Epic'),
  VipAnimal(level: 9, name: 'Cobra', emoji: '🐍', category: 'Land', rarity: 'Epic'),
  VipAnimal(level: 10, name: 'Lion', emoji: '🦁', category: 'Land', rarity: 'Epic'),
  VipAnimal(level: 11, name: 'Tiger', emoji: '🐯', category: 'Land', rarity: 'Epic'),
  VipAnimal(level: 12, name: 'Mammoth', emoji: '🦣', category: 'Land', rarity: 'Legendary'),
  VipAnimal(level: 13, name: 'Gorilla', emoji: '🦍', category: 'Land', rarity: 'Legendary'),
  VipAnimal(level: 14, name: 'Bear', emoji: '🐻', category: 'Land', rarity: 'Legendary'),
  VipAnimal(level: 15, name: 'Kraken', emoji: '🐙', category: 'Water', rarity: 'Legendary'),
  VipAnimal(level: 16, name: 'Leviathan', emoji: '🐉', category: 'Water', rarity: 'Mythic'),
  VipAnimal(level: 17, name: 'Phoenix', emoji: '🐦‍🔥', category: 'Air', rarity: 'Mythic'),
  VipAnimal(level: 18, name: 'Dragon', emoji: '🐉', category: 'Air', rarity: 'Mythic'),
];

VipAnimal vipAnimalFor(int level) =>
    vipAnimals[(level.clamp(1, 18)) - 1];

Color _rarityColor(String rarity) {
  switch (rarity) {
    case 'Epic':
      return const Color(0xFFB388FF);
    case 'Legendary':
      return const Color(0xFFFFB11B);
    case 'Mythic':
      return const Color(0xFFFF3A24);
    default:
      return const Color(0xFF4CC8FF);
  }
}

/// Black + gold + purple palette. No brown anywhere.
///
/// Purple is used tastefully, never as a full-screen wash: deep purple
/// gradients behind the central animal emblem (stronger at higher tiers),
/// a gold-to-purple progress fill, a purple glow on the selected tab,
/// and a purple tint on unlocked cards. Black backgrounds and gold
/// frames, text and ornaments stay the base.
class VipSectionColors {
  VipSectionColors._();

  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0D0D0D);
  static const Color surfaceRaised = Color(0xFF161616);
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDeep = Color(0xFFFFB11B);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color goldPale = Color(0xFFFFF2A6);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textDim = Color(0xFFBFBFBF);
  static const Color divider = Color(0xFF2A2A2A);

  // Purple accent: deep purple, main purple, bright purple, soft purple.
  static const Color purple = Color(0xFF7B2FBE);
  static const Color purpleDeep = Color(0xFF6A1B9A);
  static const Color purpleBright = Color(0xFF9B32FF);
  static const Color purpleSoft = Color(0xFFB388FF);
  // Purple-tinted card surface (black with a deep-purple wash).
  static const Color purpleSurface = Color(0xFF1A0B2E);
  static const Color purpleGlow = Color(0x557B2FBE);
  static const Color goldGlow = Color(0x66FFD700);

  /// Emblem radial-gradient colours for a VIP level. VIP1-9 stay
  /// gold-dominant with only a faint purple edge; VIP10-15 blend purple
  /// and gold; VIP16-18 are purple-dominant with a gold ring kept.
  static List<Color> emblemGradient(int level) {
    if (level >= 16) {
      return const <Color>[Color(0xFF6A1B9A), Color(0xFF2A0A44), Color(0xFF000000)];
    }
    if (level >= 10) {
      return const <Color>[Color(0xFF4A1D6B), Color(0xFF2A2200), Color(0xFF000000)];
    }
    return const <Color>[Color(0xFF2A2200), Color(0xFF1A0B2E), Color(0xFF000000)];
  }

  /// Emblem glow colour for a VIP level: gold at low tiers, purple at
  /// the top tiers, a blend in between.
  static Color emblemGlow(int level) {
    if (level >= 16) return const Color(0xAA9B32FF);
    if (level >= 10) return const Color(0x889B32FF);
    return goldGlow;
  }

  /// Progress-bar fill gradient: gold into purple, stronger purple at
  /// higher tiers.
  static List<Color> progressGradient(int level) {
    if (level >= 16) {
      return const <Color>[Color(0xFFFFD700), Color(0xFF7B2FBE), Color(0xFF9B32FF)];
    }
    return const <Color>[Color(0xFFFFD700), Color(0xFFFFB11B), Color(0xFF7B2FBE)];
  }

  /// Dragon-frame glow: purple fire, stronger at the top tiers.
  /// VIP1-9 subtle, VIP10-15 medium, VIP16-18 strongest.
  static double dragonFrameBlur(int level) {
    if (level >= 16) return 56;
    if (level >= 10) return 44;
    return 36;
  }

  static double dragonFrameSpread(int level) {
    if (level >= 16) return 10;
    if (level >= 10) return 8;
    return 5;
  }
}

/// Optional WIN banner (reference screenshot 3: "Lucky Gift won").
/// Shown only when [win] is not null.
class VipWinBanner {
  const VipWinBanner({
    required this.title,
    required this.subtitle,
    required this.multiplier,
  });

  final String title;
  final String subtitle;
  final String multiplier;
}

/// The new VIP section screen, black + gold + purple, modelled on the reference.
class VipSectionScreen extends StatefulWidget {
  const VipSectionScreen({
    super.key,
    required this.currentLevel,
    required this.active,
    required this.vipExpBalance,
    required this.monthlyPoints,
    this.win,
    this.onBack,
    this.onHelp,
    this.onSettings,
    this.onRecharge,
    this.onRecord,
  });

  final int currentLevel;
  final bool active;
  final int vipExpBalance;
  final int monthlyPoints;
  final VipWinBanner? win;
  final VoidCallback? onBack;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;
  final VoidCallback? onRecharge;
  final VoidCallback? onRecord;

  @override
  State<VipSectionScreen> createState() => _VipSectionScreenState();
}

class _VipSectionScreenState extends State<VipSectionScreen> {
  late int _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.currentLevel.clamp(1, VipPolicy.maxLevel);
  }

  @override
  Widget build(BuildContext context) {
    final animal = vipAnimalFor(_selectedLevel);
    final nextRule = _selectedLevel < VipPolicy.maxLevel
        ? VipPolicy.ruleFor(_selectedLevel + 1)
        : null;
    final target = nextRule?.upgradeExp ?? 1;
    final progress = _selectedLevel >= VipPolicy.maxLevel
        ? 1.0
        : (widget.vipExpBalance / target).clamp(0.0, 1.0).toDouble();
    final pointsNeeded = _selectedLevel >= VipPolicy.maxLevel
        ? 0
        : (target - widget.vipExpBalance).clamp(0, target).toInt();
    final isCurrent = _selectedLevel == widget.currentLevel;

    return Scaffold(
      backgroundColor: VipSectionColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TopBar(
                onBack: widget.onBack,
                onHelp: widget.onHelp,
                onSettings: widget.onSettings,
              ),
              if (widget.win != null) _WinBanner(win: widget.win!),
              _LevelTabs(
                selected: _selectedLevel,
                onSelect: (level) => setState(() => _selectedLevel = level),
              ),
              _Emblem(animal: animal, selectedLevel: _selectedLevel),
              _ProgressBar(
                progress: progress,
                selectedLevel: _selectedLevel,
                pointsNeeded: pointsNeeded,
                isMax: _selectedLevel >= VipPolicy.maxLevel,
              ),
              const _GoldDivider(),
              _SectionTitle(title: 'VIP Identity'),
              _IdentityGrid(
                selectedLevel: _selectedLevel,
                animal: animal,
                currentLevel: widget.currentLevel,
              ),
              _SectionTitle(title: 'Exclusive Privileges'),
              _PrivilegesGrid(
                selectedLevel: _selectedLevel,
                currentLevel: widget.currentLevel,
                active: widget.active,
              ),
              _RechargeBanner(
                active: widget.active && isCurrent,
                monthlyPoints: widget.monthlyPoints,
                selectedLevel: _selectedLevel,
                onRecharge: widget.onRecharge,
                onRecord: widget.onRecord,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, this.onHelp, this.onSettings});

  final VoidCallback? onBack;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded,
                color: VipSectionColors.gold, size: 34),
          ),
          const Spacer(),
          IconButton(
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline_rounded,
                color: VipSectionColors.gold, size: 28),
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined,
                color: VipSectionColors.gold, size: 28),
          ),
        ],
      ),
    );
  }
}

class _WinBanner extends StatelessWidget {
  const _WinBanner({required this.win});

  final VipWinBanner win;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          // Gold + black with a purple tint; no red, per the palette.
          colors: <Color>[Color(0xFF161616), Color(0xFF1A0B2E), Color(0xFF000000)],
        ),
        border: Border.all(color: VipSectionColors.gold, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 24,
            backgroundColor: VipSectionColors.surfaceRaised,
            child: Text('🏆', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  win.title,
                  style: const TextStyle(
                    color: VipSectionColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  win.subtitle,
                  style: const TextStyle(
                    color: VipSectionColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            win.multiplier,
            style: const TextStyle(
              color: VipSectionColors.gold,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTabs extends StatelessWidget {
  const _LevelTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: VipPolicy.maxLevel,
        itemBuilder: (context, index) {
          final level = index + 1;
          final isSelected = level == selected;
          return GestureDetector(
            onTap: () => onSelect(level),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? VipSectionColors.gold
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: isSelected
                    ? BoxDecoration(
                        color: VipSectionColors.purpleSurface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: VipSectionColors.purpleGlow,
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      )
                    : null,
                child: Text(
                  'VIP$level',
                style: TextStyle(
                  color: isSelected
                      ? VipSectionColors.gold
                      : VipSectionColors.textDim,
                  fontSize: isSelected ? 20 : 16,
                  fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.animal, required this.selectedLevel});

  final VipAnimal animal;
  final int selectedLevel;

  @override
  Widget build(BuildContext context) {
    // Real animal artwork: the level's transparent frame still from R2
    // (frames/vip<N>-<animal>-transparent.png). Falls back to the animal
    // emoji only if the R2 image fails to load.
    final String? frameStillUrl =
        vipFrameStillUrlForVipLevel(selectedLevel);
    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        // Gold ring + purple glow frame around the emblem, tiered by
        // level: glow strengthens at VIP10+ and peaks at VIP16-18.
        // (Vinay, 2026-11-20: the dragon-frame style is NOT applied —
        // the per-level animal frames stay as they are.)
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 254,
              height: 254,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: VipSectionColors.goldDeep, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: VipSectionColors.emblemGlow(selectedLevel),
                    blurRadius:
                        VipSectionColors.dragonFrameBlur(selectedLevel),
                    spreadRadius:
                        VipSectionColors.dragonFrameSpread(selectedLevel),
                  ),
                ],
              ),
            ),
            Container(
              width: 238,
              height: 238,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: VipSectionColors.gold, width: 2),
              ),
            ),
            Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Purple gradient behind the emblem, stronger at higher tiers;
                // the gold ring is kept at every tier.
                gradient: RadialGradient(
                  colors: VipSectionColors.emblemGradient(selectedLevel),
                ),
                border: Border.all(color: VipSectionColors.gold, width: 3),
              ),
              alignment: Alignment.center,
              child: frameStillUrl != null
                  ? ClipOval(
                      child: Image.network(
                        frameStillUrl,
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(animal.emoji,
                            style: const TextStyle(fontSize: 110)),
                      ),
                    )
                  : Text(animal.emoji,
                      style: const TextStyle(fontSize: 110)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Golden VIP tag image for all 18 levels, loaded from R2.
        VipTagImage(vipLevel: selectedLevel, fontSize: 20),
        const SizedBox(height: 8),
        Text(
          '${animal.name}  •  ${animal.category}  •  ${animal.rarity}',
          style: TextStyle(
            color: _rarityColor(animal.rarity),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 200,
          height: 10,
          decoration: BoxDecoration(
            color: VipSectionColors.surfaceRaised,
            border: Border.all(color: VipSectionColors.goldDark),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.selectedLevel,
    required this.pointsNeeded,
    required this.isMax,
  });

  final double progress;
  final int selectedLevel;
  final int pointsNeeded;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: VipSectionColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          // Gold-to-purple progress fill.
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: VipSectionColors.progressGradient(
                                  selectedLevel),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'VIP$selectedLevel',
                style: const TextStyle(
                  color: VipSectionColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isMax
                ? 'You have reached the highest VIP level.'
                : 'Need ${_formatNumber(pointsNeeded)} points more to VIP${selectedLevel + 1}',
            style: const TextStyle(
              color: VipSectionColors.text,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Divider(color: VipSectionColors.goldDark, thickness: 2),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: VipSectionColors.gold,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Expanded(
            child: Divider(color: VipSectionColors.goldDark, thickness: 2),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('—  ◆  —',
              style: TextStyle(color: VipSectionColors.gold)),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: VipSectionColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          const Text('—  ◆  —',
              style: TextStyle(color: VipSectionColors.gold)),
        ],
      ),
    );
  }
}

class _IdentityItem {
  const _IdentityItem({
    required this.label,
    required this.icon,
    required this.minLevel,
    this.note,
    this.isNew = false,
  });

  final String label;
  final IconData icon;
  final int minLevel;
  final String? note;
  final bool isNew;
}

List<_IdentityItem> _identityItems(VipAnimal animal) {
  // Real coins bonus from the VIP policy (coinsBonusForPurchase):
  // +5% at VIP5, +10% at VIP11, +20% at VIP16.
  final int coinsBonus = animal.level >= 16
      ? 20
      : animal.level >= 11
          ? 10
          : animal.level >= 5
              ? 5
              : 0;
  return <_IdentityItem>[
    _IdentityItem(
      label: coinsBonus > 0 ? 'Coins Bonus +$coinsBonus%' : 'Coins Bonus',
      icon: Icons.monetization_on_rounded,
      minLevel: 5,
      note: coinsBonus > 0 ? 'On every purchase' : 'From VIP5',
    ),
    const _IdentityItem(
      label: 'Label',
      icon: Icons.label_rounded,
      minLevel: 1,
    ),
    const _IdentityItem(
      label: 'VIP Medal',
      icon: Icons.military_tech_rounded,
      minLevel: 1,
    ),
    const _IdentityItem(
      label: 'Frame',
      icon: Icons.filter_frames_rounded,
      minLevel: 1,
      note: 'Animal frame',
    ),
    const _IdentityItem(
      label: 'Profile Card',
      icon: Icons.credit_card_rounded,
      minLevel: 5,
    ),
    _IdentityItem(
      label: 'Ride: ${animal.name}',
      icon: Icons.directions_rounded,
      minLevel: 5,
    ),
    const _IdentityItem(
      label: 'Chat Bubble',
      icon: Icons.chat_bubble_rounded,
      minLevel: 2,
    ),
    // Gift banner / gift ribbon EXISTS in the app now
    // (gift_ribbon_banner.dart + R2 gift-ribbons/).
    const _IdentityItem(
      label: 'Gift Banner',
      icon: Icons.card_giftcard_rounded,
      minLevel: 1,
      isNew: true,
    ),
  ];
}

class _IdentityGrid extends StatelessWidget {
  const _IdentityGrid({
    required this.selectedLevel,
    required this.animal,
    required this.currentLevel,
  });

  final int selectedLevel;
  final VipAnimal animal;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final items = _identityItems(animal);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final unlocked = currentLevel >= item.minLevel;
          return _RewardCard(item: item, unlocked: unlocked);
        },
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.item, required this.unlocked});

  final _IdentityItem item;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Unlocked cards get a purple tint over the black surface;
        // locked cards stay plain black. Gold border is kept.
        gradient: unlocked
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  VipSectionColors.purpleSurface,
                  VipSectionColors.surface,
                ],
              )
            : null,
        color: unlocked ? null : VipSectionColors.surface,
        border: Border.all(
          color: unlocked
              ? VipSectionColors.gold
              : VipSectionColors.divider,
          width: unlocked ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (item.isNew)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: VipSectionColors.gold,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Icon(
            item.icon,
            color: unlocked
                ? VipSectionColors.gold
                : VipSectionColors.textDim,
            size: 34,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: unlocked
                    ? VipSectionColors.text
                    : VipSectionColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (item.note != null)
            Text(
              item.note!,
              style: const TextStyle(
                color: VipSectionColors.goldDeep,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrivilegeItem {
  const _PrivilegeItem({
    required this.title,
    required this.icon,
    required this.minLevel,
  });

  final String title;
  final IconData icon;
  final int minLevel;
}

// Privileges shown in the reference, mapped to real VipPolicy entries.
const List<_PrivilegeItem> _privilegeItems = <_PrivilegeItem>[
  _PrivilegeItem(
    title: 'View Visitor Record',
    icon: Icons.visibility_rounded,
    minLevel: 1,
  ),
  _PrivilegeItem(
    title: 'Priority CS Support',
    icon: Icons.support_agent_rounded,
    minLevel: 9,
  ),
  _PrivilegeItem(
    title: 'Room Online List on Top',
    icon: Icons.arrow_upward_rounded,
    minLevel: 1,
  ),
  _PrivilegeItem(
    title: 'Custom Profile Background',
    icon: Icons.image_rounded,
    minLevel: 17,
  ),
  // EXP boost EXISTS in DarkVibeX (worker expBoostForLevel: 1.1x at VIP1,
  // 1.2x at VIP5, 1.4x at VIP11, 1.5x at VIP16). "More Profile Background"
  // has no matching entry and is NOT shown.
  _PrivilegeItem(
    title: 'Exp 110% Speed up',
    icon: Icons.rocket_launch_rounded,
    minLevel: 1,
  ),
  _PrivilegeItem(
    title: 'Hide Visit Record',
    icon: Icons.visibility_off_rounded,
    minLevel: 11,
  ),
  _PrivilegeItem(
    title: 'Golden Name',
    icon: Icons.text_fields_rounded,
    minLevel: 8,
  ),
  _PrivilegeItem(
    title: 'Custom Room Background',
    icon: Icons.wallpaper_rounded,
    minLevel: 3,
  ),
];

class _PrivilegesGrid extends StatelessWidget {
  const _PrivilegesGrid({
    required this.selectedLevel,
    required this.currentLevel,
    required this.active,
  });

  final int selectedLevel;
  final int currentLevel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _privilegeItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final item = _privilegeItems[index];
          final unlocked =
              active && currentLevel >= item.minLevel;
          return Container(
            decoration: BoxDecoration(
              // Unlocked privileges get a purple tint; gold border kept.
              gradient: unlocked
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        VipSectionColors.purpleSurface,
                        VipSectionColors.surface,
                      ],
                    )
                  : null,
              color: unlocked ? null : VipSectionColors.surface,
              border: Border.all(
                color: unlocked
                    ? VipSectionColors.gold
                    : VipSectionColors.divider,
                width: unlocked ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unlocked
                          ? VipSectionColors.gold
                          : VipSectionColors.textDim,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: unlocked
                        ? VipSectionColors.gold
                        : VipSectionColors.textDim,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: unlocked
                          ? VipSectionColors.text
                          : VipSectionColors.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RechargeBanner extends StatelessWidget {
  const _RechargeBanner({
    required this.active,
    required this.monthlyPoints,
    required this.selectedLevel,
    this.onRecharge,
    this.onRecord,
  });

  final bool active;
  final int monthlyPoints;
  final int selectedLevel;
  final VoidCallback? onRecharge;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            VipSectionColors.surfaceRaised,
            VipSectionColors.purpleSurface,
          ],
        ),
        border: Border.all(color: VipSectionColors.gold, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              GestureDetector(
                onTap: onRecord,
                child: const Row(
                  children: <Widget>[
                    Text(
                      'Record',
                      style: TextStyle(
                        color: VipSectionColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: VipSectionColors.text, size: 18),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 24,
                backgroundColor: VipSectionColors.surface,
                child: Text('👤', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      active
                          ? 'VIP$selectedLevel privileges are unlocked'
                          : 'VIP privileges are not unlocked yet',
                      style: const TextStyle(
                        color: VipSectionColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'VIP Points: $monthlyPoints',
                      style: const TextStyle(
                        color: VipSectionColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onRecharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VipSectionColors.gold,
                  foregroundColor: const Color(0xFF000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Recharge',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
