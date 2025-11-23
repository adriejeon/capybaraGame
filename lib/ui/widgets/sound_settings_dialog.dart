import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../sound_manager.dart';
import '../../state/locale_state.dart';

/// 사운드 설정 다이얼로그
class SoundSettingsDialog extends StatefulWidget {
  const SoundSettingsDialog({super.key});

  @override
  State<SoundSettingsDialog> createState() => _SoundSettingsDialogState();
}

class _SoundSettingsDialogState extends State<SoundSettingsDialog> {
  final SoundManager _soundManager = SoundManager();
  late bool _isSoundEffectEnabled;
  late bool _isBgmEnabled;

  @override
  void initState() {
    super.initState();
    _isSoundEffectEnabled = _soundManager.isSoundEffectEnabled;
    _isBgmEnabled = _soundManager.isBgmEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Color(0xFF4A90E2),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.settingsTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5F8B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 효과음 설정
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6F3FF)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.volume_up,
                    color: _isSoundEffectEnabled
                        ? const Color(0xFF4A90E2)
                        : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.soundEffects,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C5F8B),
                      ),
                    ),
                  ),
                  Switch(
                    value: _isSoundEffectEnabled,
                    onChanged: (value) async {
                      await _soundManager.toggleSoundEffect();
                      setState(() {
                        _isSoundEffectEnabled = value;
                      });
                    },
                    activeColor: const Color(0xFF4A90E2),
                    activeTrackColor: const Color(0xFF4A90E2).withOpacity(0.3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 배경음 설정
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6F3FF)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color:
                        _isBgmEnabled ? const Color(0xFF4A90E2) : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.backgroundMusic,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C5F8B),
                      ),
                    ),
                  ),
                  Switch(
                    value: _isBgmEnabled,
                    onChanged: (value) async {
                      await _soundManager.toggleBgm();
                      setState(() {
                        _isBgmEnabled = value;
                      });
                    },
                    activeColor: const Color(0xFF4A90E2),
                    activeTrackColor: const Color(0xFF4A90E2).withOpacity(0.3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 언어 설정
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6F3FF)),
              ),
              child: Consumer<LocaleState>(
                builder: (context, localeState, child) {
                  final currentLocale = localeState.currentLocale;

                  return Row(
                    children: [
                      const Icon(
                        Icons.language,
                        color: Color(0xFF4A90E2),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.language,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2C5F8B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<Locale>(
                        value: currentLocale,
                        underline: Container(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF4A90E2),
                        ),
                        items: [
                          DropdownMenuItem<Locale>(
                            value: const Locale('ko', 'KR'),
                            child: Text(
                              AppLocalizations.of(context)!.languageKorean,
                              style: const TextStyle(
                                color: Color(0xFF2C5F8B),
                              ),
                            ),
                          ),
                          DropdownMenuItem<Locale>(
                            value: const Locale('en', 'US'),
                            child: Text(
                              AppLocalizations.of(context)!.languageEnglish,
                              style: const TextStyle(
                                color: Color(0xFF2C5F8B),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (Locale? newLocale) {
                          if (newLocale != null) {
                            localeState.changeLocale(newLocale);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 닫기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  AppLocalizations.of(context)!.confirm,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
