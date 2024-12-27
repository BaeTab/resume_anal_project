class ResumeAnalysisModel {
  final String extractedText;
  final String analysisResult;
  final DateTime analysisDate;

  ResumeAnalysisModel({
    required this.extractedText,
    required this.analysisResult,
    DateTime? analysisDate,
  }) : analysisDate = analysisDate ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'extractedText': extractedText,
      'analysisResult': analysisResult,
      'analysisDate': analysisDate.toIso8601String(),
    };
  }

  factory ResumeAnalysisModel.fromJson(Map<String, dynamic> json) {
    return ResumeAnalysisModel(
      extractedText: json['extractedText'] ?? '',
      analysisResult: json['analysisResult'] ?? '',
      analysisDate: json['analysisDate'] != null 
        ? DateTime.parse(json['analysisDate']) 
        : DateTime.now(),
    );
  }
}
