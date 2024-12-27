import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/text_normalizer.dart';

class ApiService {
  // 서버 주소 (개발 환경에서는 PC의 실제 IP 주소로 변경)
  static const String baseUrl = 'http://192.168.0.100:5000';

  // 이력서 분석 API (개선된 버전)
  static Future<Map<String, dynamic>> analyzeResume(Uint8List pdfBytes) async {
    try {
      // PDF 파일을 Base64로 인코딩
      String base64Pdf = base64Encode(pdfBytes);

      // API 요청
      final response = await http.post(
        Uri.parse('$baseUrl/analyze_resume'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'pdf_file': base64Pdf,
        }),
      ).timeout(
        Duration(seconds: 60),  // 타임아웃 시간 연장
        onTimeout: () {
          throw Exception('서버 응답 시간 초과');
        },
      );

      // 응답 처리
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final extractedText = responseBody['analysis'] ?? '';

        // 텍스트 정규화
        final normalizedText = TextNormalizer.normalize(extractedText);

        // 텍스트 유효성 검사
        if (!TextNormalizer.isValidText(normalizedText)) {
          return {
            'status': 'warning',
            'message': '추출된 텍스트의 품질이 낮습니다. 다시 시도해주세요.',
            'analysis': null
          };
        }

        // 섹션 분류
        final sections = TextNormalizer.classifySections(normalizedText);

        return {
          'status': 'success',
          'analysis': {
            'raw_text': extractedText,
            'normalized_text': normalizedText,
            'sections': sections
          }
        };
      } else {
        return {
          'status': 'error',
          'message': json.decode(response.body)['message'] ?? '분석 중 오류 발생'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': '서버 연결 중 오류 발생: $e'
      };
    }
  }

  // 추가: 로깅 및 오류 추적 메서드
  static void _logError(String message) {
    // 실제 프로덕션 환경에서는 로깅 라이브러리 사용 권장
    print('[ApiService Error] $message');
  }

  // 서버 상태 확인
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('서버 응답 없음'),
      );

      final responseBody = json.decode(response.body);
      return response.statusCode == 200 && responseBody['status'] == 'healthy';
    } catch (e) {
      print('서버 상태 확인 실패: $e');
      return false;
    }
  }
}
