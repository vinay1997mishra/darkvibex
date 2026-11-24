// Join the family page (Mr. Wrong, 2026-11-24): the family list with
// "+ apply for" buttons and member counts ("44/45"), on the v9 light
// glass purple+gold background. Empty state: "There is currently no
// family available to join in your area. You can create it yourself."
// + "Create a family" button.
//
// NOTE: the Lucky Wheel banner at the top of the other app's join page
// is the Daily Lucky Wheel EVENT — the spin is on HOLD (his words:
// "event ka chod diyo abhi"), so the banner here is a static header
// with no wheel and no spin. The wheel itself is built only when he
// says so.
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:flutter/material.dart';
import 'create_family_screen.dart';
import 'family_common.dart';
import 'family_detail_screen.dart';

class FamilyJoinScreen extends StatefulWidget {
  const FamilyJoinScreen({super.key, required this.state, this.backend});

  final AppState state;

  /// Test seam: a fake backend. Defaults to [AppState.backend].
  final BackendApi? backend;

  @override
  State<FamilyJoinScreen> createState() => _FamilyJoinScreenState();
}

class _FamilyJoinScreenState extends State<FamilyJoinScreen> {
  BackendApi get _backend => widget.backend ?? widget.state.backend;

  bool _loading = true;
  List<Map<String, dynamic>> _families = const [];
  final Set<String> _applied = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await _backend.familyList();
    if (!mounted) return;
    setState(() {
      _families = values;
      _loading = false;
    });
  }

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _apply(Map<String, dynamic> family) async {
    final familyId = family['id']?.toString() ?? '';
    if (familyId.isEmpty) return;
    final result = await _backend.requestFamilyJoin(
      userId: widget.state.userId,
      familyId: familyId,
    );
    if (!mounted) return;
    // Direct join (open family): the user is a member right now — pop
    // back to Top Families with `true` so it reloads and shows the
    // family instead of the stale "not joined yet" page (Mr. Wrong,
    // 2026-11-24: join dabane ke baad bhi family me join nahi dikh
    // raha tha — the old code stayed on this page saying "Applied").
    if (result.joined) {
      Navigator.pop(context, true);
      return;
    }
    if (result.ok) {
      setState(() => _applied.add(familyId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the application')),
      );
    }
  }

  void _openDetail(Map<String, dynamic> family) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyDetailScreen(
          state: widget.state,
          familyId: family['id']?.toString() ?? '',
          backend: widget.backend,
        ),
      ),
    );
  }

  Future<void> _create() async {
    final created = await Navigator.push<String?>(
      context,
      MaterialPageRoute<String?>(
        builder: (_) => CreateFamilyScreen(state: widget.state),
      ),
    );
    if (created != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: familyAppBar(
          'join the family',
          actions: [
            IconButton(
              key: const Key('family-join-rules'),
              icon: const Icon(Icons.help_outline),
              tooltip: 'Family Rules',
              onPressed: () => openFamilyRules(context),
            ),
          ],
        ),
        body: FamilyBackground(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Static Lucky Wheel banner (event on hold: no wheel,
                    // no spin — header only). Richer matching colours
                    // (Mr. Wrong, 2026-11-24: "upar wale ka background
                    // aur colour thik kar, matching colour add kar, thoda
                    // different"): deep purple -> purple -> gold gradient,
                    // gold border, gloss shine + gold shadow for 3D depth.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFF5E35B1),
                              Color(0xFF8E24AA),
                              Color(0xFFFFB300),
                              Color(0xFFFFD54A),
                            ],
                            stops: <double>[0.0, 0.45, 0.75, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFFD54A),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66E8A91C),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Gloss shine on the top half.
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.center,
                                      colors: <Color>[
                                        Color(0x40FFFFFF),
                                        Color(0x00FFFFFF),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                child: const Column(
                                  children: [
                                    Text(
                                      'Join Family,',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x42000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Win Massive Coins',
                                      style: TextStyle(
                                        color: Color(0xFFFFD54A),
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x42000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _families.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'There is currently no family available to join in your area. You can create it yourself.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF2A2140),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    FamilyGoldButton(
                                      key: const Key('family-join-create'),
                                      label: 'Create a family',
                                      onPressed: _create,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _families.length,
                              itemBuilder: (context, index) {
                                final family = _families[index];
                                final familyId =
                                    family['id']?.toString() ?? '';
                                final memberCount =
                                    _asInt(family['member_count']);
                                final memberLimit =
                                    _asInt(family['member_limit']);
                                final full = memberLimit > 0 &&
                                    memberCount >= memberLimit;
                                final applied = _applied.contains(familyId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: FamilyCard(
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _openDetail(family),
                                          child: FamilyAvatar(
                                            backend: _backend,
                                            avatarKey: family['logo_key']
                                                    ?.toString() ??
                                                '',
                                            size: 56,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _openDetail(family),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  family['name']
                                                          ?.toString() ??
                                                      'Family',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: Color(0xFF2A2140),
                                                  ),
                                                ),
                                                if ((family['notice']
                                                            ?.toString() ??
                                                        '')
                                                    .isNotEmpty)
                                                  Text(
                                                    family['notice']
                                                        .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color:
                                                          Color(0xFF4A4458),
                                                    ),
                                                  ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  memberLimit > 0
                                                      ? '$memberCount/$memberLimit'
                                                      : '$memberCount members',
                                                  style: const TextStyle(
                                                    color: Color(0xFF7A7390),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          key: Key(
                                            'family-join-apply-$familyId',
                                          ),
                                          onPressed: full || applied
                                              ? null
                                              : () => _apply(family),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFE8A91C),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(
                                            full
                                                ? 'Full'
                                                : applied
                                                    ? 'Applied'
                                                    : '+ apply for',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      );
}
