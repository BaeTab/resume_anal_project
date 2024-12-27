import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  late String _apiKey;

  OpenAIService() {
    // 환경 변수 로드 확인 및 API 키 초기화
    _initializeApiKey();
  }

  void _initializeApiKey() {
    try {
      // dotenv 초기화 확인 및 API 키 로드
      if (!dotenv.isInitialized) {
        dotenv.load(fileName: ".env");
      }
      _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

      if (_apiKey.isEmpty) {
        throw Exception('OpenAI API 키가 설정되지 않았습니다.');
      }
    } catch (e) {
      print('API 키 초기화 오류: $e');
      throw Exception('API 키를 로드할 수 없습니다.');
    }
  }

  Future<String> analyzeResume(String resumeText) async {
    try {
      // API 키 유효성 재확인
      if (_apiKey.isEmpty) {
        _initializeApiKey();
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: utf8.encode(jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '다음 이력서 텍스트를 전문적으로 분석해주세요. 강점, 개선점, 키워드, 산업 트렌드와의 일치도 등을 상세히 평가해주세요. 분석 결과는 한국어로 명확하고 구체적으로 작성해주세요.',
            },
            {
              'role': 'user',
              'content': resumeText,
            }
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        })),
      );

      if (response.statusCode == 200) {
        // UTF-8로 디코딩하여 한글 깨짐 방지
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        return jsonResponse['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('OpenAI API 요청 실패: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      print('이력서 분석 중 오류: $e');
      rethrow;
    }
  }
}
