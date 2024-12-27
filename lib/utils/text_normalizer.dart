// 텍스트 정규화를 위한 유틸리티 함수
class TextNormalizer {
  static String normalize(String text) {
    if (text.isEmpty) return '';

    // 불필요한 공백 제거
    text = text.trim();

    // 연속된 공백 제거
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // 특수 문자 및 제어 문자 처리 (유니코드 지원)
    text = text.replaceAll(RegExp(r'[^\p{L}\p{N}\p{P}\s]', unicode: true), '');

    // 줄바꿈 정규화
    text = text.replaceAll(RegExp(r'\r\n|\r|\n'), ' ');

    // 과도한 공백 제거
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');

    // 문장 사이 추가 공백 제거
    text = text.replaceAll(RegExp(r'\s([.,!?:;])'), r'\1');

    // 문장 시작 부분 대문자로 변환
    text = _capitalizeFirstLetter(text);

    return text.trim();
  }

  // 문장의 첫 글자를 대문자로 변환하는 메서드
  static String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // 텍스트의 품질을 평가하는 메서드 (개선)
  static bool isValidText(String text, {int minLength = 50, int maxLength = 5000}) {
    if (text.isEmpty) return false;
    
    // 의미 있는 단어의 최소 길이 확인
    final words = text.split(RegExp(r'\s+'));
    final meaningfulWords = words.where((word) => word.length > 2);

    return meaningfulWords.length > 5 && 
           text.length >= minLength && 
           text.length <= maxLength;
  }

  // 정보 섹션 분류 메서드 추가
  static Map<String, String> classifySections(String text) {
    final sections = <String, String>{};
    
    // 정규 표현식을 사용한 섹션 분류
    final sectionPatterns = {
      '개인정보': r'(이름|성명|연락처|이메일|주소)',
      '학력': r'(학력|교육|학교|전공|졸업)',
      '경력': r'(경력|경력사항|근무|회사|직무)',
      '기술': r'(기술|스킬|역량|언어|프로그래밍)',
      '프로젝트': r'(프로젝트|프로젝트 경험)',
    };

    sectionPatterns.forEach((sectionName, pattern) {
      final sectionMatch = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (sectionMatch != null) {
        final startIndex = sectionMatch.start;
        final endIndex = text.indexOf(RegExp(r'\n\s*\n'), startIndex);
        
        sections[sectionName] = endIndex != -1 
          ? text.substring(startIndex, endIndex).trim() 
          : text.substring(startIndex).trim();
      }
    });

    return sections;
  }
}

// 전역 함수로 사용할 수 있는 편의 함수
String normalizeText(String text) {
  return TextNormalizer.normalize(text);
}
