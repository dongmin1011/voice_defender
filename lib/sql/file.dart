import 'dart:convert';

class File_table {
  int? id;
  String? filename;
  String? created_at;
  bool? is_phising;
  double? confidence;
  String? Text;
  bool? is_deep_voice;
  double? deep_voice_confidence;
  String? reasons;

  File_table({
    this.id,
    this.filename,
    this.created_at,
    this.is_phising,
    this.confidence,
    this.Text,
    this.is_deep_voice,
    this.deep_voice_confidence,
    this.reasons,
  });
  Map<String, dynamic> toMap() {
    final reasonsJson = jsonEncode(reasons);
    print(reasonsJson);
    return {
      'id': id,
      'filename': filename,
      'created_at': created_at,
      'is_phising': is_phising,
      'confidence': confidence,
      'Text': Text,
      'is_deep_voice': is_deep_voice,
      'deep_voice_confidence': deep_voice_confidence,
      'reasons': reasonsJson
    };
  }
}
