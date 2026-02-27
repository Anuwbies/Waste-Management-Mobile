/// LLM-powered disposal guide model.
///
/// Maps to the backend `POST /waste/suggestion` response:
/// ```json
/// {
///   "title": "How to dispose Plastic properly",
///   "bin": "Blue",
///   "steps": ["Step 1", "Step 2"],
///   "doNot": ["Do not …"],
///   "tips": ["Tip 1"],
///   "safety": ["Safety note"]
/// }
/// ```
class DisposalGuide {
  /// Short title, e.g. "How to dispose Plastic properly"
  final String title;

  /// Recommended bin colour or collection type
  final String bin;

  /// 3-5 numbered disposal steps
  final List<String> steps;

  /// Common mistakes to avoid
  final List<String> doNot;

  /// Practical advice / eco tips
  final List<String> tips;

  /// Safety notes (empty when none apply)
  final List<String> safety;

  const DisposalGuide({
    required this.title,
    required this.bin,
    this.steps = const [],
    this.doNot = const [],
    this.tips = const [],
    this.safety = const [],
  });

  factory DisposalGuide.fromJson(Map<String, dynamic> json) {
    return DisposalGuide(
      title: json['title'] as String? ?? 'Disposal Guide',
      bin: json['bin'] as String? ?? 'Unknown',
      steps: _stringList(json['steps']),
      doNot: _stringList(json['doNot']),
      tips: _stringList(json['tips']),
      safety: _stringList(json['safety']),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'bin': bin,
        'steps': steps,
        'doNot': doNot,
        'tips': tips,
        'safety': safety,
      };

  /// Helper: safely cast a dynamic list to `List<String>`.
  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  /// Low-confidence / unrecognised-item placeholder (no LLM call needed).
  static const DisposalGuide lowConfidence = DisposalGuide(
    title: 'Unable to Identify Item',
    bin: 'Unknown',
    steps: ['Please retake the photo with better lighting.'],
    doNot: [],
    tips: ['Make sure the object is clearly visible.'],
    safety: [],
  );

  @override
  String toString() =>
      'DisposalGuide(title=$title, bin=$bin, steps=${steps.length}, '
      'doNot=${doNot.length}, tips=${tips.length}, safety=${safety.length})';
}
