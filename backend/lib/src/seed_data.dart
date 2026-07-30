import 'models/tag.dart';
import 'repositories/tag_repository.dart';

/// Seeds the shared, extensible tag list (NFR5). User accounts are no
/// longer seeded — real accounts are created via POST /api/register.
///
/// Idempotent: does nothing if tags already exist, so restarting the
/// server against an existing data file never duplicates seed data.
Future<void> seedDatabase({required TagRepository tagRepository}) async {
  final existingTags = await tagRepository.getAll();
  if (existingTags.isNotEmpty) return;

  final tags = [
    Tag(id: 1, name: 'Artificial Intelligence'),
    Tag(id: 2, name: 'Web Development'),
    Tag(id: 3, name: 'Mobile Development'),
    Tag(id: 4, name: 'Databases'),
    Tag(id: 5, name: 'Networks & Security'),
    Tag(id: 6, name: 'Cloud Computing'),
    Tag(id: 7, name: 'Human-Computer Interaction'),
    Tag(id: 8, name: 'Data Science'),
  ];
  for (final tag in tags) {
    await tagRepository.insert(tag);
  }
}
