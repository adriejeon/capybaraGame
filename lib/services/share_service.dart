import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class ShareService {
  static const String _smartLink = 'https://onelink.to/73hdmp';
  static const String _nativeAppKey = '941590ef92057f63649c0c5b886f918c';
  static const String _gameShareLink =
      'https://adriejeon.github.io/capybaraPolicy/share.html';
  static const String _gameShareLinkEn =
      'https://adriejeon.github.io/capybaraPolicy/share-en.html';

  /// 게임 스코어 공유하기 - 배달의민족 방식 (이미지 제외, 텍스트 + 링크만)
  static Future<void> shareGameScore({
    required int score,
    required String difficulty,
    required int gameTime, // 게임 완료 시간 (초)
    required BuildContext context,
  }) async {
    final locale = Localizations.localeOf(context);
    final isKorean = locale.languageCode == 'ko';

    // 난이도 텍스트 변환
    String difficultyText;
    if (isKorean) {
      difficultyText = difficulty == 'easy'
          ? '쉬움'
          : difficulty == 'medium'
              ? '보통'
              : '어려움';
    } else {
      difficultyText = difficulty == 'easy'
          ? 'Easy'
          : difficulty == 'medium'
              ? 'Normal'
              : 'Hard';
    }

    // 게임 완료 시간 포맷
    final timeText = GameHelpers.formatTime(gameTime);

    // 공유 링크 선택
    final shareLink = isKorean ? _gameShareLink : _gameShareLinkEn;

    // 배달의민족 방식 메시지 생성 (이미지 제외, 텍스트 + 링크만)
    final message = isKorean
        ? '🐾 카피바라 짝 맞추기 게임\n\n난이도: $difficultyText\n점수: $score점\n시간: $timeText\n\n친구야 너도 이 점수 낼 수 있어?\n\n게임 다운로드: $shareLink'
        : '🐾 Capybara Match Game\n\nDifficulty: $difficultyText\nScore: $score points\nTime: $timeText\n\nCan you beat my score?\n\nDownload Game: $shareLink';

    // share_plus를 사용하여 공유 (배달의민족 방식)
    await Share.share(message);
  }

  /// 컬렉션 캐릭터 공유하기 - 공유 방법 선택 바텀 시트 표시
  static Future<void> shareCharacter({
    required String characterImagePath,
    required BuildContext context,
  }) async {
    final locale = Localizations.localeOf(context);
    final isKorean = locale.languageCode == 'ko';

    // 바텀 시트로 공유 방법 선택
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  isKorean ? '공유하기' : 'Share',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.chat_bubble, color: Color(0xFFFAE100)),
                title: Text(isKorean ? '카카오톡으로 공유' : 'Share via KakaoTalk'),
                onTap: () {
                  Navigator.pop(context);
                  _shareCharacterToKakao(
                      characterImagePath: characterImagePath, context: context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.message, color: Color(0xFF4A90E2)),
                title: Text(isKorean ? '문자 메시지로 공유' : 'Share via SMS'),
                onTap: () {
                  Navigator.pop(context);
                  _shareCharacterToSMS(
                      characterImagePath: characterImagePath, context: context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 카카오톡으로 캐릭터 공유 (내부 메서드)
  static Future<void> _shareCharacterToKakao({
    required String characterImagePath,
    required BuildContext context,
  }) async {
    try {
      final locale = Localizations.localeOf(context);
      final isKorean = locale.languageCode == 'ko';

      // 캐릭터 이미지 경로를 GitHub raw URL로 변환
      final imageName = characterImagePath.split('/').last;
      final githubImageUrl =
          'https://github.com/adriejeon/capybaraGame/blob/main/assets/capybara/collection/$imageName?raw=true';

      // 카카오 Feed Template을 사용하여 썸네일이 있는 카드 형태로 공유
      final template = FeedTemplate(
        content: Content(
          title: isKorean ? '카피바라 짝 맞추기 게임' : 'Capybara Match Game',
          description: isKorean
              ? '귀여운 카피바라를 모았어! 너도 같이 해볼래?'
              : 'I collected this cute capybara! Want to play together?',
          imageUrl: Uri.parse(githubImageUrl),
          link: Link(
            webUrl: Uri.parse(_smartLink),
            mobileWebUrl: Uri.parse(_smartLink),
          ),
        ),
        buttons: [
          Button(
            title: isKorean ? '나도 게임하기' : 'Play Game',
            link: Link(
              webUrl: Uri.parse(_smartLink),
              mobileWebUrl: Uri.parse(_smartLink),
            ),
          ),
        ],
      );

      // 카카오톡 설치 여부 확인
      bool isKakaoTalkSharingAvailable =
          await ShareClient.instance.isKakaoTalkSharingAvailable();

      if (isKakaoTalkSharingAvailable) {
        // 카카오톡 설치되어 있음
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      } else {
        // 카카오톡 미설치 - 웹 공유로 대체
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      }
    } catch (e) {
      print('카카오톡 캐릭터 공유 오류: $e');
      print('상세 오류: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ko'
                ? '카카오톡 공유에 실패했습니다. 카카오톡이 설치되어 있는지 확인해주세요.'
                : 'Failed to share via KakaoTalk. Please check if KakaoTalk is installed.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 문자 메시지로 캐릭터 공유 (내부 메서드)
  static Future<void> _shareCharacterToSMS({
    required String characterImagePath,
    required BuildContext context,
  }) async {
    try {
      final byteData = await rootBundle.load(characterImagePath);
      final buffer = byteData.buffer;
      final tempDir = await getTemporaryDirectory();
      final fileName = characterImagePath.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      final locale = Localizations.localeOf(context);
      final isKorean = locale.languageCode == 'ko';
      final message = isKorean
          ? '카피바라 짝 맞추기 게임에서 귀여운 카피바라를 모았어!\n게임 다운로드: $_smartLink'
          : 'I collected this cute capybara!\nDownload: $_smartLink';

      await Share.shareXFiles([XFile(file.path)], text: message);
    } catch (e) {
      print('문자 메시지 캐릭터 공유 오류: $e');
    }
  }
}
