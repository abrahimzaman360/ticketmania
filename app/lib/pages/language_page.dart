import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../providers/locale_provider.dart';

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeService = ref.watch(localeServiceProvider);
    final currentLocale = localeService.locale;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: LocaleService.supportedLanguages.map((lang) {
                final isSelected = currentLocale.languageCode == lang['code'];
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                      ),
                      title: Text(lang['name']!),
                      subtitle: Text(lang['nativeName']!),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () async {
                        await localeService.setLocale(Locale(lang['code']!));
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Language changed to ${lang['name']}'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                      },
                    ),
                    if (lang != LocaleService.supportedLanguages.last)
                      const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

