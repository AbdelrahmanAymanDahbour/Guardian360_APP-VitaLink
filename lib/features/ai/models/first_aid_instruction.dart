/// Represents one offline first-aid topic shown inside Guardian AI.
///
/// This model is intentionally simple:
/// - No UI logic.
/// - No network logic.
/// - No localization logic.
/// - Content is provided by FirstAidContentService.
class FirstAidInstruction {
  const FirstAidInstruction({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.summary,
    required this.steps,
  });

  /// Stable identifier used by UI icons, lookup, and quick actions.
  final String id;

  /// Full title shown in the detailed first-aid sheet.
  final String title;

  /// Short label shown in compact cards or quick actions.
  final String shortTitle;

  /// Brief explanation shown before the detailed steps.
  final String summary;

  /// Ordered practical steps for this first-aid case.
  final List<FirstAidStep> steps;
}

/// Represents one practical first-aid step.
///
/// Keep each step focused, clear, and safe for emergency situations.
class FirstAidStep {
  const FirstAidStep({required this.title, required this.description});

  /// Short action title.
  final String title;

  /// Clear explanation of what the user should do.
  final String description;
}
