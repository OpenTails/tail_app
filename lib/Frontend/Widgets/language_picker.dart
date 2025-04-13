import 'package:choice/choice.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../l10n/app_localizations.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

class LanguagePicker extends ConsumerWidget {
  final bool isButton;

  const LanguagePicker({
    super.key,
    this.isButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PromptedChoice<Locale>.single(
      title: appLanguageSelectorTitle(),
      promptDelegate: ChoicePrompt.delegateBottomSheet(
          useRootNavigator: true, enableDrag: true, maxHeightFactor: 0.8),
      itemCount: AppLocalizations.supportedLocales.length,
      modalHeaderBuilder: ChoiceModal.createHeader(
        automaticallyImplyLeading: true,
        actionsBuilder: [],
      ),
      anchorBuilder: (state, openModal) {
        if (isButton) {
          return OverflowBar(
            alignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: openModal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    Text(appLanguageSelectorTitle())
                  ],
                ),
              ),
            ],
          );
        } else {
          return ListTile(
            onTap: openModal,
            title: Text(appLanguageSelectorTitle()),
            leading: Icon(Icons.language),
            subtitle:
                state.single != null ? Text(state.single!.toString()) : null,
          );
        }
      },
      modalFooterBuilder: ChoiceModal.createFooter(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          (choiceController) {
            return FilledButton(
              onPressed: choiceController.value.isNotEmpty
                  ? () => choiceController.closeModal(confirmed: true)
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Text(
                    triggersDefSelectSaveLabel(),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: getTextColor(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  ),
                ],
              ),
            );
          },
        ],
      ),
      onChanged: (value) async {
        if (value != null) {
          HiveProxy.put(settings, selectedLocale, value.toLanguageTag());
          ref.invalidate(initLocaleProvider);
        }
      },
      confirmation: true,
      value: AppLocalizations.supportedLocales
          .where(
            (element) =>
                element.toLanguageTag() ==
                HiveProxy.getOrDefault(settings, selectedLocale,
                    defaultValue: ""),
          )
          .firstOrNull,
      itemBuilder: (ChoiceController<Locale> state, int index) {
        Locale locale = AppLocalizations.supportedLocales[index];
        return RadioListTile(
          value: locale,
          onChanged: (Locale? value) {
            state.select(locale);
          },
          groupValue: state.single,
          title: Text(LocaleNames.of(context)!
                  .nameOf(locale.toLanguageTag().replaceAll("-", "_")) ??
              locale.toLanguageTag()),
          secondary: Builder(builder: (context) {
            if (locale.countryCode != null) {
              return CountryFlag.fromCountryCode(
                  locale.countryCode!.replaceAll("zh", "zh-cn"));
            } else {
              return CountryFlag.fromLanguageCode(
                  locale.languageCode.replaceAll("zh", "zh-cn"));
            }
          }),
        );
      },
    );
  }
}
