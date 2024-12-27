import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../utils/text_normalizer.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _extractedText = '';
  bool _isAnalyzing = false;
  String _errorMessage = '';

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
        SnackBar(content: Text('먼저 PDF를 분석해주세요.')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // Firestore에 분석 결과 저장
      await _firestore.collection('resume_analyses').add({
        'userId': user.uid,
        'fileName': _selectedFileName,
        'analyzedText': _extractedText,
        'analyzedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과가 성공적으로 저장되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 결과 저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _viewAnalysisHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // 사용자의 분석 이력 쿼리
      final querySnapshot = await _firestore
          .collection('resume_analyses')
          .where('userId', isEqualTo: user.uid)
          .orderBy('analyzedAt', descending: true)
          .get();

      // 분석 이력 보기 다이얼로그
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('분석 이력'),
          content: querySnapshot.docs.isEmpty
            ? Text('분석된 이력서가 없습니다.')
            : SingleChildScrollView(
                child: Column(
                  children: querySnapshot.docs.map((doc) {
                    final data = doc.data();
                    return ListTile(
                      title: Text(data['fileName'] ?? '알 수 없는 파일'),
                      subtitle: Text('분석 일시: ${data['analyzedAt']?.toDate()}'),
                      onTap: () {
                        // 분석 결과 상세보기
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('분석 결과'),
                            content: SingleChildScrollView(
                              child: Text(data['analyzedText']),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('닫기'),
                              ),
                            ],
                          ),
                        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 이력 조회 중 오류가 발생했습니다: $e')),
      );
    }
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
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _extractedText,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.left,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveAnalysisResult,
                          child: Text('분석 결과 저장'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
