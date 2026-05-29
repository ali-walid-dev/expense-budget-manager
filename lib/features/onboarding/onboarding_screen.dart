import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  final _pc = PageController();
  int _index = 0;
  String _lang = 'en';
  String _currency = 'EGP';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      _Slide(title: l.onboardingTitle1, body: l.onboardingBody1, icon: Icons.bolt),
      _Slide(title: l.onboardingTitle2, body: l.onboardingBody2, icon: Icons.insights),
      _Slide(title: l.onboardingTitle3, body: l.onboardingBody3, icon: Icons.savings),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  ...pages,
                  _LangCurrencyPage(
                    lang: _lang,
                    currency: _currency,
                    onLang: (v) => setState(() => _lang = v),
                    onCurrency: (v) => setState(() => _currency = v),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final selected = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: selected ? 24 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () async {
                  if (_index < 3) {
                    _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  } else {
                    final settings = ref.read(settingsProvider.notifier);
                    await settings.setLanguage(_lang);
                    await settings.setCurrency(_currency);
                    await settings.markOnboarded();
                    await ref.read(seedDataProvider.future);
                    if (context.mounted) context.go(AppRoutes.dashboard);
                  }
                },
                child: Text(_index < 3 ? l.more : l.getStarted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.title, required this.body, required this.icon});
  final String title, body;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _LangCurrencyPage extends StatelessWidget {
  const _LangCurrencyPage({
    required this.lang,
    required this.currency,
    required this.onLang,
    required this.onCurrency,
  });
  final String lang, currency;
  final ValueChanged<String> onLang;
  final ValueChanged<String> onCurrency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pickLanguage, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {lang},
            onSelectionChanged: (s) => onLang(s.first),
          ),
          const SizedBox(height: 24),
          Text(l.pickCurrency, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final c in const ['EGP', 'USD', 'EUR', 'SAR', 'AED', 'GBP'])
                ChoiceChip(
                  label: Text(c),
                  selected: c == currency,
                  onSelected: (_) => onCurrency(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
