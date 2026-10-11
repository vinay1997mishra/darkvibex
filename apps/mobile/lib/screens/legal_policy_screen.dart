import 'package:flutter/material.dart';

/// In-app DarkVibeX policy text. Review and replace with the operator's
/// jurisdiction-specific legal text before a public launch.
class LegalPolicyScreen extends StatelessWidget {
  const LegalPolicyScreen({super.key, this.showAgreement = false});

  final bool showAgreement;

  static const terms = <(String, String)>[
    ('Using DarkVibeX', 'DarkVibeX is a free social voice-room app. You must use your own account, follow the law, and keep your sign-in details secure. You are responsible for activity from your account.'),
    ('Room chat and conduct', 'Do not post threats, hate, harassment, sexual content involving minors, scams, impersonation, spam, or unlawful material. Do not share another person’s private information without permission. Room owners and moderators may manage room access and remove content.'),
    ('Voice, photos and messages', 'Only share voice, photos and messages that you have the right to share. Other room participants may hear, view, or save content shown to them. Do not assume that room conversations are private.'),
    ('Virtual items and balances', 'Coins, diamonds, gifts and other in-app items are virtual app features. They are not cash, have no cash value, and cannot be withdrawn or transferred as real money through DarkVibeX. The app does not promise a real-money payout.'),
    ('Safety and enforcement', 'We may restrict access to rooms or accounts when needed to protect users, enforce these rules, or respond to legal requirements. You can leave a room or stop using the app at any time.'),
    ('Changes and support', 'Features and these terms may change as the free app develops. The current in-app version applies when you use the app. Contact the app operator through the support channel provided with your app distribution.'),
  ];

  static const privacy = <(String, String)>[
    ('Information used', 'The app may process your DarkVibeX user ID, display name, profile and room photos, room membership and seat status, messages you send, and settings needed to operate the features you use. When you sign in with Google, the app uses the account identity returned for sign-in.'),
    ('How it is used', 'This information is used to sign you in, show your profile and room, deliver messages, operate voice rooms, maintain balances and safety controls, and troubleshoot service problems.'),
    ('Service providers', 'Information may pass through the server, database, image storage, and voice provider configured for DarkVibeX. The app only needs microphone or camera access when you choose the corresponding room feature.'),
    ('Sharing and visibility', 'Room messages and room activity can be seen by room participants. Direct messages are available to their sender and recipient. Profile and room photos are visible where those profiles or rooms appear. Do not send information you do not want other participants to see.'),
    ('Retention and control', 'Information is kept as needed to operate the service and its safety records. You can stop using the app and sign out. The current app does not provide an in-app account deletion control; contact the app operator through the support channel provided with your app distribution to request help.'),
    ('Policy changes', 'This notice describes the app features currently implemented and may be updated when data handling changes. Check this screen for the current notice.'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terms & Privacy'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Terms'),
            Tab(text: 'Privacy'),
          ]),
        ),
        body: TabBarView(children: [
          _PolicyPage(sections: terms, intro: 'DarkVibeX • Free voice and chat app'),
          _PolicyPage(sections: privacy, intro: 'Privacy notice • DarkVibeX'),
        ]),
      ),
    );
  }
}

class _PolicyPage extends StatelessWidget {
  const _PolicyPage({required this.sections, required this.intro});

  final List<(String, String)> sections;
  final String intro;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(intro, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final section in sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(section.$2),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('This in-app notice is a product description, not a substitute for legal review by the app operator.'),
          ),
        ],
      );
}
