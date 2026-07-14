import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// ML Kit 온디바이스 번역 (무료·오프라인 — iOS/Android 공통).
/// 언어 자동 감지 → 필요 시 모델 다운로드 → 번역.
/// HanChatConfig.translationService가 주입되면 이 경로 대신 그쪽을 쓴다 (Phase 4: AI).
class MLKitTranslator {
  MLKitTranslator._();
  static final instance = MLKitTranslator._();

  final _languageId = LanguageIdentifier(confidenceThreshold: 0.3);
  final _modelManager = OnDeviceTranslatorModelManager();

  Future<String?> translate(String text, {required String toLanguageCode}) async {
    try {
      var sourceCode = await _languageId.identifyLanguage(text);
      if (sourceCode == 'und') {
        // 짧은 문장은 감지 실패가 잦음 → 문자 기반 폴백
        sourceCode = _guessByScript(text);
      }

      final source = _language(sourceCode);
      final target = _language(toLanguageCode);
      if (source == null || target == null || source == target) return null;

      // 모델 없으면 다운로드 (언어당 1회, 이후 오프라인)
      for (final lang in [source, target]) {
        if (!await _modelManager.isModelDownloaded(lang.bcpCode)) {
          await _modelManager.downloadModel(lang.bcpCode);
        }
      }

      final translator =
          OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
      try {
        return await translator.translateText(text);
      } finally {
        await translator.close();
      }
    } catch (_) {
      return null;
    }
  }

  String _guessByScript(String text) {
    if (RegExp(r'[가-힣]').hasMatch(text)) return 'ko';
    if (RegExp(r'[぀-ヿ]').hasMatch(text)) return 'ja'; // 가나
    if (RegExp(r'[一-鿿]').hasMatch(text)) return 'zh'; // 한자
    return 'en';
  }

  TranslateLanguage? _language(String code) {
    final normalized = code.split('-').first.toLowerCase();
    for (final lang in TranslateLanguage.values) {
      if (lang.bcpCode == normalized) return lang;
    }
    return null;
  }
}
