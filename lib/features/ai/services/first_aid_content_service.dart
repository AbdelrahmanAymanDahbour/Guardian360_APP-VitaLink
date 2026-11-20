import '../models/first_aid_instruction.dart';

/// Offline first-aid catalog.
///
/// The service exposes stable localization keys only; translated content lives
/// in assets/langs/*.json and is rendered in the View layer.
class FirstAidContentService {
  const FirstAidContentService._();

  static const List<FirstAidInstruction> quickActions = [
    FirstAidInstruction(
      id: 'bleeding',
      title: 'ai.first_aid.bleeding.title',
      shortTitle: 'ai.first_aid.bleeding.short_title',
      summary: 'ai.first_aid.bleeding.summary',
      steps: [
        FirstAidStep(
          title: 'ai.first_aid.bleeding.steps.0.title',
          description: 'ai.first_aid.bleeding.steps.0.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.bleeding.steps.1.title',
          description: 'ai.first_aid.bleeding.steps.1.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.bleeding.steps.2.title',
          description: 'ai.first_aid.bleeding.steps.2.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.bleeding.steps.3.title',
          description: 'ai.first_aid.bleeding.steps.3.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.bleeding.steps.4.title',
          description: 'ai.first_aid.bleeding.steps.4.description',
        ),
      ],
    ),
    FirstAidInstruction(
      id: 'unconscious',
      title: 'ai.first_aid.unconscious.title',
      shortTitle: 'ai.first_aid.unconscious.short_title',
      summary: 'ai.first_aid.unconscious.summary',
      steps: [
        FirstAidStep(
          title: 'ai.first_aid.unconscious.steps.0.title',
          description: 'ai.first_aid.unconscious.steps.0.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.unconscious.steps.1.title',
          description: 'ai.first_aid.unconscious.steps.1.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.unconscious.steps.2.title',
          description: 'ai.first_aid.unconscious.steps.2.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.unconscious.steps.3.title',
          description: 'ai.first_aid.unconscious.steps.3.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.unconscious.steps.4.title',
          description: 'ai.first_aid.unconscious.steps.4.description',
        ),
      ],
    ),
    FirstAidInstruction(
      id: 'fracture',
      title: 'ai.first_aid.fracture.title',
      shortTitle: 'ai.first_aid.fracture.short_title',
      summary: 'ai.first_aid.fracture.summary',
      steps: [
        FirstAidStep(
          title: 'ai.first_aid.fracture.steps.0.title',
          description: 'ai.first_aid.fracture.steps.0.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.fracture.steps.1.title',
          description: 'ai.first_aid.fracture.steps.1.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.fracture.steps.2.title',
          description: 'ai.first_aid.fracture.steps.2.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.fracture.steps.3.title',
          description: 'ai.first_aid.fracture.steps.3.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.fracture.steps.4.title',
          description: 'ai.first_aid.fracture.steps.4.description',
        ),
      ],
    ),
    FirstAidInstruction(
      id: 'burns',
      title: 'ai.first_aid.burns.title',
      shortTitle: 'ai.first_aid.burns.short_title',
      summary: 'ai.first_aid.burns.summary',
      steps: [
        FirstAidStep(
          title: 'ai.first_aid.burns.steps.0.title',
          description: 'ai.first_aid.burns.steps.0.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.burns.steps.1.title',
          description: 'ai.first_aid.burns.steps.1.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.burns.steps.2.title',
          description: 'ai.first_aid.burns.steps.2.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.burns.steps.3.title',
          description: 'ai.first_aid.burns.steps.3.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.burns.steps.4.title',
          description: 'ai.first_aid.burns.steps.4.description',
        ),
      ],
    ),
    FirstAidInstruction(
      id: 'cpr',
      title: 'ai.first_aid.cpr.title',
      shortTitle: 'ai.first_aid.cpr.short_title',
      summary: 'ai.first_aid.cpr.summary',
      steps: [
        FirstAidStep(
          title: 'ai.first_aid.cpr.steps.0.title',
          description: 'ai.first_aid.cpr.steps.0.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.cpr.steps.1.title',
          description: 'ai.first_aid.cpr.steps.1.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.cpr.steps.2.title',
          description: 'ai.first_aid.cpr.steps.2.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.cpr.steps.3.title',
          description: 'ai.first_aid.cpr.steps.3.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.cpr.steps.4.title',
          description: 'ai.first_aid.cpr.steps.4.description',
        ),
      ],
    ),
    FirstAidInstruction(
      id: 'choking',
      title: 'ai.first_aid.choking.title',
      shortTitle: 'ai.first_aid.choking.short_title',
      summary: 'ai.first_aid.choking.summary',
      steps: [
        FirstAidStep(
          title: 'ai.first_aid.choking.steps.0.title',
          description: 'ai.first_aid.choking.steps.0.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.choking.steps.1.title',
          description: 'ai.first_aid.choking.steps.1.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.choking.steps.2.title',
          description: 'ai.first_aid.choking.steps.2.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.choking.steps.3.title',
          description: 'ai.first_aid.choking.steps.3.description',
        ),
        FirstAidStep(
          title: 'ai.first_aid.choking.steps.4.title',
          description: 'ai.first_aid.choking.steps.4.description',
        ),
      ],
    ),
  ];

  static FirstAidInstruction? findById(String id) {
    final safeId = id.trim();

    if (safeId.isEmpty) return null;

    for (final instruction in quickActions) {
      if (instruction.id == safeId) return instruction;
    }

    return null;
  }
}
