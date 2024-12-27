import 'package:flutter/material.dart';
import 'dart:typed_data';

class AnalysisScreen extends StatelessWidget {
  final String analysisResult;
  final Uint8List originalPdfBytes;

  const AnalysisScreen({
    Key? key, 
    required this.analysisResult, 
    required this.originalPdfBytes
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이력서 분석 결과'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '분석 결과',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              analysisResult,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
