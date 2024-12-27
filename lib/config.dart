import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // 환경 변수에서 API 키 로드
  static String get openAIApiKey {
    // dotenv에서 API 키 로드, 없으면 빈 문자열 반환
    return dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  // API 키 유효성 검사 메서드
  static bool isApiKeyValid() {
    return openAIApiKey.isNotEmpty && 
           openAIApiKey.startsWith('sk-') && 
           openAIApiKey.length > 40;
  }
}
