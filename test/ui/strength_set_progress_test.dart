import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:hilt_mobile/src/football_library.dart';
import 'package:hilt_mobile/src/l10n/app_localizations.dart';
import 'package:hilt_mobile/src/screens/dashboard_screen.dart';

void main() {
  final l10n = AppLocalizations(const Locale('en'));

  List<SportProfile> allStrengthProfiles() {
    return [
      ...FootballLibrary.getStrengthPresetsForGear(GarageGear.barbell),
      ...FootballLibrary.getStrengthPresetsForGear(GarageGear.dumbbells),
      ...FootballLibrary.getStrengthPresetsForGear(GarageGear.bench),
      ...FootballLibrary.getStrengthPresetsForGear(GarageGear.noEquipment),
    ];
  }

  test('all strength sessions open on set 1 of the first block', () {
    for (final profile in allStrengthProfiles()) {
      expect(
        profile.blocks,
        isNotEmpty,
        reason: '${profile.displayName} should define at least one block',
      );

      final firstBlockSets = profile.blocks.first.iterations;
      expect(
        strengthSetProgressLabel(
          l10n: l10n,
          completedSets: 0,
          totalSets: firstBlockSets,
        ),
        'SET 1/$firstBlockSets',
        reason: '${profile.displayName} should not open on set 2',
      );
    }
  });

  test('strength set label advances after a completed set is logged', () {
    expect(
      strengthSetProgressLabel(
        l10n: l10n,
        completedSets: 1,
        totalSets: 4,
      ),
      'SET 2/4',
    );
  });
}
