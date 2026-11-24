import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zing/config/business_config.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

/// Help & Support: ways to reach the ZING team and answers to common
/// questions from customers and store owners.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) {
      showZingToast(context, 'Could not open ${uri.scheme == 'mailto' ? 'email' : 'that app'}',
          error: true);
    }
  }

  static const _customerFaq = [
    (
      'How do I place an order?',
      'Open a store, add products to your bag, then go to the Cart tab and choose Store Pickup or Home Delivery. You can also tap Buy Now on a product to order it straight away.'
    ),
    (
      'How do I pay?',
      'Orders are paid to the store directly — in cash on pickup or on delivery, unless the store tells you otherwise in chat.'
    ),
    (
      'Where can I see my order status?',
      'The Orders tab shows every order with its live status. You also get a notification whenever the store updates it.'
    ),
    (
      'Can I talk to a store before buying?',
      'Yes. Tap Chat on any store page. Messages can be translated with one tap.'
    ),
  ];

  static const _ownerFaq = [
    (
      'How do I list my store?',
      'Create an account as a store owner, open Store Management from your profile, and add your store details, photos, location and products.'
    ),
    (
      'How does the subscription work?',
      'Store access lasts 30 days from each approved payment. Pay by bank transfer using the details on the Renew screen, then send us the receipt. We activate your store once it is confirmed.'
    ),
    (
      'Why is my store not visible to customers?',
      'Stores are hidden while the subscription is not active. Check the days left on your Store Management dashboard and renew if needed.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final phone = _digits(BusinessConfig.supportPhoneDisplay);
    final whatsapp = _digits(BusinessConfig.supportWhatsAppDisplay).replaceAll('+', '');

    return ZingLargeTitlePage(
      title: 'Help & Support',
      showBack: true,
      slivers: [
        SliverToBoxAdapter(
          child: ZingReveal(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'We usually reply within a few hours, 9 am – 6 pm, Monday to Saturday.',
                style: ZingType.subhead(cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: const Duration(milliseconds: 60),
            child: ZingGroupedSection(
              header: 'Contact us',
              children: [
                ZingListRow(
                  icon: CupertinoIcons.phone_fill,
                  iconColor: ZingColors.success,
                  title: 'Call',
                  value: BusinessConfig.supportPhoneDisplay,
                  onTap: () => _open(context, Uri(scheme: 'tel', path: phone)),
                ),
                ZingListRow(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  iconColor: const Color(0xFF25D366),
                  title: 'WhatsApp',
                  value: BusinessConfig.supportWhatsAppDisplay,
                  onTap: () => _open(context, Uri.parse('https://wa.me/$whatsapp')),
                ),
                ZingListRow(
                  icon: CupertinoIcons.envelope_fill,
                  iconColor: ZingColors.accent,
                  title: 'Email',
                  subtitle: BusinessConfig.supportEmail,
                  onTap: () => _open(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: BusinessConfig.supportEmail,
                      query: 'subject=${Uri.encodeComponent('ZING app support')}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: const Duration(milliseconds: 120),
            child: ZingGroupedSection(
              header: 'Shopping',
              separatorIndent: 16,
              children: [for (final q in _customerFaq) _FaqRow(question: q.$1, answer: q.$2)],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ZingReveal(
            child: ZingGroupedSection(
              header: 'For store owners',
              separatorIndent: 16,
              footer: 'Still stuck? Contact us above and include your store name.',
              children: [for (final q in _ownerFaq) _FaqRow(question: q.$1, answer: q.$2)],
            ),
          ),
        ),
      ],
    );
  }
}

/// A question that expands in place to reveal its answer.
class _FaqRow extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqRow({required this.question, required this.answer});

  @override
  State<_FaqRow> createState() => _FaqRowState();
}

class _FaqRowState extends State<_FaqRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.question, style: ZingType.body(cs.onSurface))),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: ZingMotion.medium,
                  curve: ZingMotion.emphasized,
                  child: Icon(CupertinoIcons.chevron_forward,
                      size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              ],
            ),
            AnimatedSize(
              duration: ZingMotion.medium,
              curve: ZingMotion.emphasized,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, right: 16),
                      child: Text(widget.answer, style: ZingType.subhead(cs.onSurfaceVariant)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
