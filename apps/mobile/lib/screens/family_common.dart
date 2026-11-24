// Shared pieces for the Family pages (Mr. Wrong, 2026-11-24): every
// Family page uses the SAME v9 light glass purple+gold background
// (family_bg_light.png) — NOT the other app's dark background.
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/infra/family_rules.dart';
import 'package:flutter/material.dart';

/// The v9 Family background: light glass purple+gold.
///
/// Set [vivid] for pages where the pale glass reads almost white and the
/// purple+gold must show clearly (Mr. Wrong, 2026-11-24, Party page):
/// a purple-to-gold gradient wash is painted over the glass image, under
/// the content, so the page reads purple+gold instead of white.
class FamilyBackground extends StatelessWidget {
  const FamilyBackground({super.key, required this.child, this.vivid = false});

  final Widget child;
  final bool vivid;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/family_bg_light.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: vivid
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x667B2FBE),
                      Color(0x338B5CF6),
                      Color(0x59FFD54A),
                      Color(0x88E8A91C),
                    ],
                    stops: [0, .3, .6, 1],
                  ),
                ),
                child: child,
              )
            : child,
      );
}

/// Dark app bar shared by the Family pages (same as the Create page).
AppBar familyAppBar(String title, {List<Widget>? actions}) => AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: const Color(0xFF17112E),
      foregroundColor: Colors.white,
      actions: actions,
    );

/// A frosted-glass card on the light background.
class FamilyCard extends StatelessWidget {
  const FamilyCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8C96A), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}

/// Gold gradient button (same as the Create page's create button).
class FamilyGoldButton extends StatelessWidget {
  const FamilyGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFFD54A), Color(0xFFE8A91C)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: const Color(0xFF5A3E00),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(label),
          ),
        ),
      );
}

/// A user's avatar from an R2 key, with a fallback person icon.
class FamilyAvatar extends StatelessWidget {
  const FamilyAvatar({
    super.key,
    required this.backend,
    required this.avatarKey,
    this.size = 48,
  });

  final BackendApi backend;
  final String avatarKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = avatarKey.trim();
    if (key.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFF7E57C2),
        child: Icon(Icons.person, size: size * 0.6, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: NetworkImage(backend.fileUrl(key)),
      onBackgroundImageError: (_, __) {},
      backgroundColor: const Color(0xFF7E57C2),
      child: Icon(Icons.person, size: size * 0.6, color: Colors.white),
    );
  }
}

/// Section title inside a Family page (dark text on the light glass).
class FamilySectionTitle extends StatelessWidget {
  const FamilySectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF2A2140),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

/// A small gold progress bar (family EXP / rank progress).
class FamilyProgressBar extends StatelessWidget {
  const FamilyProgressBar({super.key, required this.progress});

  /// 0.0 - 1.0.
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFFE8DFF5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFD54A), Color(0xFFE8A91C)],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      );
}

/// Open the Family Rules screen ("?" button).
void openFamilyRules(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const FamilyRulesScreen()),
  );
}

class FamilyRulesScreen extends StatelessWidget {
  const FamilyRulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: familyAppBar('Family Rules'),
        body: FamilyBackground(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: familyRulesSections.length,
            itemBuilder: (context, index) {
              final section = familyRulesSections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FamilyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          color: Color(0xFF2A2140),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.body,
                        style: const TextStyle(
                          color: Color(0xFF4A4458),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
}
