class AccidentAnalysisResult {
  final bool isAccident;

  /// Severity score on a 0-100 scale
  final double severityScore;

  /// خفيف، متوسط، خطير، حرج جداً
  final String severityLevel;

  /// رسالة النظام
  final String recommendation;

  AccidentAnalysisResult({
    required this.isAccident,
    required this.severityScore,
    required this.severityLevel,
    required this.recommendation,
  });
}
