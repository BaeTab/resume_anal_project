import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp, FieldValue;

import '../utils/text_normalizer.dart';
import '../services/openai_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _openAIService = OpenAIService();

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _extractedText = '';
  bool _isAnalyzing = false;
  String _errorMessage = '';
  String _aiAnalysisResult = '';
  bool _isAIAnalyzing = false;
  bool _isLoading = false;

  // 텍스트 편집 모드 상태 변수 추가
  bool _isEditingText = false;
  late TextEditingController _textEditingController;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = 'application/pdf';
      input.click();

      input.onChange.listen((event) {
        if (input.files != null && input.files!.length > 0) {
          final html.File file = input.files![0];
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((event) {
            setState(() {
              _selectedFileBytes = reader.result as Uint8List?;
              _selectedFileName = file.name;
            });
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'PDF 파일 선택 중 오류 발생: $e';
      });
    }
  }

  Future<String> _extractPdfText(Uint8List pdfBytes) async {
    try {
      // PDF 문서 로드
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      String extractedText = '';

      // 모든 페이지의 텍스트 추출
      for (int i = 0; i < document.pages.count; i++) {
        // 페이지 텍스트 추출
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        
        extractedText += pageText + '\n';
      }

      // 문서 닫기
      document.dispose();

      return extractedText;
    } catch (e) {
      setState(() {
        _errorMessage = 'PDF 텍스트 추출 중 오류 발생: $e';
      });
      return '텍스트 추출에 실패했습니다: $e';
    }
  }

  Future<void> _analyzePdf() async {
    if (_selectedFileBytes == null) {
      setState(() {
        _errorMessage = 'PDF 파일을 먼저 선택해주세요.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = '';
    });

    try {
      // PDF 텍스트 추출
      final extractedText = await _extractPdfText(_selectedFileBytes!);

      setState(() {
        _extractedText = _improveExtractedText(_normalizeText(extractedText));
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'PDF 텍스트 추출 중 오류 발생: $e';
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  String _improveExtractedText(String text) {
    // 1. 불필요한 공백 제거
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 2. 경력 정보 포맷팅
    // 회사명, 직무, 날짜, 기간, 연봉 등을 인식하여 줄바꿈
    text = text.replaceAll(
        RegExp(r'(\d{4}\.\d{2}|\d{4}년\s*\d+월?)\s*~\s*(\d{4}\.\d{2}|\d{4}년\s*\d+월?)'), 
        "\n${0}\n"
      )
      .replaceAll(
        RegExp(r'(주식회사|회사|기업|(주))\s*'), 
        "${1}\n"
      )
      .replaceAll(
        RegExp(r'(책임|수석|선임|주임|사원|연구원|엔지니어|매니저|개발자|디자이너|마케터)'), 
        "\n${1}"
      )
      .replaceAll(
        RegExp(r'(연봉|급여)\s*:?\s*'), 
        "\n${1}: "
      );

    // 3. 연속된 줄바꿈 제거
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 4. 특수 문자 정리
    text = text.replaceAll(RegExp(r'[^\w\s가-힣.,():~\-]'), ' ');

    return text;
  }

  String _normalizeText(String text) {
    return normalizeText(text);
  }

  Future<void> _saveAnalysisResult() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('먼저 텍스트를 추출해주세요.')),
      );
      return;
    }

    try {
      // 현재 로그인된 사용자 확인
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // Firestore에 분석 결과 저장 (권한 확인 로직 추가)
      final userDoc = await _firestore.collection('user_profiles').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // 사용자 프로필이 없으면 기본 프로필 생성
        await _firestore.collection('user_profiles').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? '익명 사용자',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 분석 결과 저장
      await _firestore.collection('resume_analyses').add({
        'userId': user.uid,
        'fileName': _selectedFileName ?? '알 수 없는 파일',
        'originalText': _extractedText,
        'analyzedAt': FieldValue.serverTimestamp(),
        'type': 'MANUAL_EXTRACTION',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과가 성공적으로 저장되었습니다.')),
      );
    } catch (e) {
      print('분석 결과 저장 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과 저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _viewAnalysisHistory() async {
    try {
      // 현재 로그인된 사용자 확인
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // 현재 사용자의 분석 이력 쿼리 (최근 10개)
      final querySnapshot = await _firestore
          .collection('resume_analyses')
          .where('userId', isEqualTo: user.uid)
          .get();

      // 날짜 기준으로 정렬 및 최근 10개 제한
      final sortedDocs = querySnapshot.docs
        .where((doc) => doc.data()['analyzedAt'] != null)
        .toList()
        ..sort((a, b) {
          final aDate = (a.data()['analyzedAt'] as Timestamp?)?.toDate();
          final bDate = (b.data()['analyzedAt'] as Timestamp?)?.toDate();
          return bDate?.compareTo(aDate ?? DateTime.now()) ?? 0;
        });

      final recentDocs = sortedDocs.take(10).toList();

      // 분석 이력 보기 다이얼로그
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('분석 이력'),
          content: recentDocs.isEmpty
            ? Text('분석된 이력서가 없습니다.')
            : SingleChildScrollView(
                child: Column(
                  children: recentDocs.map((doc) {
                    final data = doc.data();
                    return ListTile(
                      title: Text(data['fileName'] ?? '알 수 없는 파일'),
                      subtitle: Text(
                        '분석 일시: ${_formatTimestamp(data['analyzedAt'])} | '
                        '유형: ${_getAnalysisTypeLabel(data['type'])}',
                      ),
                      onTap: () {
                        // 분석 결과 상세보기
                        _showAnalysisDetails(data);
                      },
                    );
                  }).toList(),
                ),
              ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('닫기'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('분석 이력 조회 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 이력 조회 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 타임스탬프 포맷팅 헬퍼 메서드
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '알 수 없는 날짜';
    
    try {
      // Firestore Timestamp를 DateTime으로 변환
      DateTime dateTime = (timestamp is Timestamp) 
        ? timestamp.toDate() 
        : DateTime.parse(timestamp.toString());
      
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
             '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('타임스탬프 변환 오류: $e');
      return '날짜 형식 오류';
    }
  }

  // 분석 유형 레이블 헬퍼 메서드
  String _getAnalysisTypeLabel(String? type) {
    switch (type) {
      case 'MANUAL_EXTRACTION':
        return '수동 추출';
      case 'AI_ANALYSIS':
        return 'AI 분석';
      default:
        return '기타';
    }
  }

  // 분석 결과 상세 보기 메서드
  void _showAnalysisDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('분석 결과 상세'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('파일명: ${data['fileName'] ?? '알 수 없는 파일'}'),
              SizedBox(height: 10),
              Text('분석 일시: ${_formatTimestamp(data['analyzedAt'])}'),
              SizedBox(height: 10),
              Text('분석 유형: ${_getAnalysisTypeLabel(data['type'])}'),
              SizedBox(height: 10),
              Text('원본 텍스트:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(data['originalText'] ?? '원본 텍스트 없음'),
              SizedBox(height: 10),
              Text('분석 결과:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(data['aiAnalysisResult'] ?? '분석 결과 없음'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelectedAnalysisResult(Map<String, dynamic> data) async {
    try {
      // 현재 로그인된 사용자 확인
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // 이미 저장된 분석 결과인 경우 중복 저장 방지
      if (data.containsKey('savedToHistory') && data['savedToHistory'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미 저장된 분석 결과입니다.')),
        );
        return;
      }

      // Firestore에 분석 결과 저장
      final newDocRef = await _firestore.collection('resume_analyses').add({
        'userId': user.uid,
        'fileName': data['fileName'] ?? '알 수 없는 파일',
        'aiAnalysisResult': data['aiAnalysisResult'] ?? '분석 결과 없음',
        'analyzedAt': FieldValue.serverTimestamp(),
        'type': 'AI_ANALYSIS',
        'savedToHistory': true,
        'originalText': data['originalText'] ?? '',
      });

      // 다이얼로그 닫기
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('분석 결과가 성공적으로 저장되었습니다.'),
          action: SnackBarAction(
            label: '보기',
            onPressed: () {
              // 저장된 문서 ID로 바로 이력 조회
              _viewSpecificAnalysis(newDocRef.id);
            },
          ),
        ),
      );
    } catch (e) {
      print('분석 결과 저장 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과 저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _viewSpecificAnalysis(String docId) async {
    try {
      final doc = await _firestore.collection('resume_analyses').doc(docId).get();
      if (doc.exists) {
        _showAnalysisDetails(doc.data() ?? {});
      }
    } catch (e) {
      print('특정 분석 결과 조회 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과 조회 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _analyzeWithOpenAI() async {
    // 텍스트 유효성 검사
    if (_extractedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석할 텍스트가 없습니다.')),
      );
      return;
    }

    // 로딩 상태 설정
    setState(() {
      _isAIAnalyzing = true;
      _aiAnalysisResult = '';
    });

    try {
      // OpenAI 서비스를 통해 텍스트 분석
      final openaiService = OpenAIService();
      final analysisResult = await openaiService.analyzeResume(_extractedText);

      // 로딩 상태 해제 및 결과 저장
      setState(() {
        _isAIAnalyzing = false;
        _aiAnalysisResult = analysisResult;
      });

      // 분석 결과 저장 여부 확인 다이얼로그
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('AI 분석 결과'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('분석 결과:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text(analysisResult),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveAIAnalysisResultWrapper(_extractedText, analysisResult);
              },
              child: Text('결과 저장'),
            ),
          ],
        ),
      );
    } catch (e) {
      // 로딩 상태 해제
      setState(() {
        _isAIAnalyzing = false;
      });

      print('AI 분석 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 분석 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _saveAIAnalysisResultWrapper([String? originalText, String? aiAnalysisResult]) {
    if (originalText == null || aiAnalysisResult == null) {
      // 파라미터 없이 호출된 경우 (현재 상태의 텍스트 사용)
      if (_extractedText.isEmpty || _aiAnalysisResult.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('먼저 AI 분석을 진행해주세요.')),
        );
        return;
      }
      _saveAIAnalysisResult(_extractedText, _aiAnalysisResult);
    } else {
      // 파라미터와 함께 호출된 경우
      _saveAIAnalysisResult(originalText, aiAnalysisResult);
    }
  }

  Future<void> _saveAIAnalysisResult(String originalText, String aiAnalysisResult) async {
    try {
      // 현재 로그인된 사용자 확인
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // Firestore에 분석 결과 저장
      final newDocRef = await _firestore.collection('resume_analyses').add({
        'userId': user.uid,
        'fileName': _selectedFileName ?? '알 수 없는 파일',
        'originalText': originalText,
        'aiAnalysisResult': aiAnalysisResult,
        'analyzedAt': FieldValue.serverTimestamp(),
        'type': 'AI_ANALYSIS',
        'savedToHistory': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('분석 결과가 성공적으로 저장되었습니다.'),
          action: SnackBarAction(
            label: '보기',
            onPressed: () {
              // 저장된 문서 ID로 바로 이력 조회
              _viewSpecificAnalysis(newDocRef.id);
            },
          ),
        ),
      );
    } catch (e) {
      print('분석 결과 저장 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과 저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 텍스트 편집 토글 메서드
  void _toggleTextEditing() {
    setState(() {
      if (_isEditingText) {
        // 편집 모드에서 일반 모드로 전환 시 텍스트 업데이트
        _extractedText = _textEditingController.text;
      } else {
        // 편집 모드 진입 시 컨트롤러에 현재 텍스트 설정
        _textEditingController.text = _extractedText;
      }
      _isEditingText = !_isEditingText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('이력서 분석'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _viewAnalysisHistory,
            tooltip: '분석 이력',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              // 로그인 화면으로 이동 (main.dart의 StreamBuilder가 처리)
            },
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.upload_file),
                label: Text('PDF 파일 선택'),
                onPressed: _pickPdfFile,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              SizedBox(height: 16),
              if (_selectedFileName != null)
                Text(
                  '선택된 파일: $_selectedFileName',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.analytics_outlined),
                label: Text('텍스트 추출'),
                onPressed: _analyzePdf,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_isAnalyzing)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: 16),
              if (_extractedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '추출된 텍스트',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(_isEditingText ? Icons.check : Icons.edit),
                            onPressed: _toggleTextEditing,
                            tooltip: _isEditingText ? '편집 완료' : '텍스트 편집',
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      _isEditingText
                          ? TextField(
                              controller: _textEditingController,
                              maxLines: null,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '텍스트를 편집하세요',
                              ),
                            )
                          : Text(
                              _extractedText,
                              style: TextStyle(fontSize: 16),
                            ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isAIAnalyzing ? null : _analyzeWithOpenAI,
                        icon: _isAIAnalyzing 
                          ? SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2, 
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
                              )
                            )
                          : Icon(Icons.auto_fix_high),
                        label: Text(_isAIAnalyzing ? '분석 중...' : 'AI 분석 시작'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          backgroundColor: _isAIAnalyzing ? Colors.grey : null,
                        ),
                      ),
                      SizedBox(height: 10),
                      if (_aiAnalysisResult.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _saveAIAnalysisResultWrapper,
                          icon: Icon(Icons.save),
                          label: Text('AI 분석 결과 저장'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
