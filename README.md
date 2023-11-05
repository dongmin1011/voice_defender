# voice_defender

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# DB insert
```
final file = File_table(
          filename: response.data['filename'],
          created_at: response.data['created_at'],
          is_phising: response.data['phising_result']['is_phising'],
          confidence: response.data['phising_result']['confidence'],
          reasons: jsonEncode(response.data['phising_result']['reasons']),
          Text: response.data['phising_result']['text'],
          is_deep_voice: response.data['phising_result']['deep_voice_result']
              ['is_deep_voice'],
          deep_voice_confidence: response.data['phising_result']
              ['deep_voice_result']['confidence']);
      database.insert(file);

```
