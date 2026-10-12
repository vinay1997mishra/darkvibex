import 'package:flutter/material.dart';

import '../app/app_state.dart';

class IdLevelScreen extends StatefulWidget {
  const IdLevelScreen({super.key, required this.state});
  final AppState state;

  @override
  State<IdLevelScreen> createState() => _IdLevelScreenState();
}

class _IdLevelScreenState extends State<IdLevelScreen> {
  int _number(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    widget.state.refreshIdLevel();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final data = widget.state.idLevelState;
        final level = _number(data['level']);
        final exp = _number(data['exp_in_level']);
        final target = _number(data['next_level_exp']);
        final progress = target == 0 ? 1.0 : (exp / target).clamp(0.0, 1.0).toDouble();
        final requirements = <int>[10000, 13000, 18000, 25000, 36000];
        while (requirements.length < 100) {
          requirements.add(((requirements.last * 1.4) / 1000).round() * 1000);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('ID Level')),
          body: RefreshIndicator(
            onRefresh: widget.state.refreshIdLevel,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID Level $level / 100', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: progress, minHeight: 9),
                        const SizedBox(height: 8),
                        Text(target == 0 ? 'Maximum level reached' : '$exp / $target EXP • next level starts at 0'),
                        Text('Total earned: ${_number(data['total_exp'])} EXP'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Earn ID EXP', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const _EarnRow(title: 'Gift coin consumption', detail: '400 coins = 1 EXP'),
                const _EarnRow(title: 'Enter a room', detail: '70 EXP once per day'),
                const _EarnRow(title: 'Share a room', detail: '75 EXP once per day'),
                const _EarnRow(title: 'Aristocracy', detail: 'Accelerates upgrade; the bonus amount still needs to be defined'),
                const _EarnRow(title: 'Activities', detail: 'Can speed up upgrade; activity EXP amounts still need to be defined'),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Required EXP by level (1–100)'),
                  subtitle: const Text('Levels 1–5 confirmed; levels 6–100 use the 40% growth assumption'),
                  children: [
                    for (var index = 0; index < requirements.length; index++)
                      ListTile(
                        dense: true,
                        title: Text('Level ${index + 1}'),
                        trailing: Text('${requirements[index]} EXP'),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('When a level completes, the next level starts from 0 EXP. Any extra EXP in that same award does not roll over.', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(detail),
          dense: true,
        ),
      );
}
