import '../data/json_store.dart';
import '../models/enquiry.dart';

/// The only place that translates between [Enquiry] and the JSON store's
/// `enquiries` collection. Access-scoping (NFR4 — a staff member may only
/// see enquiries addressed to their own entries) is the Service layer's
/// responsibility, not this repository's.
class EnquiryRepository {
  static const _collection = 'enquiries';
  final JsonStore _store;

  EnquiryRepository(this._store);

  Future<List<Enquiry>> getAll() async {
    return _store.read(_collection).map(Enquiry.fromJson).toList();
  }

  Future<Enquiry?> findById(String id) async {
    final enquiries = await getAll();
    for (final enquiry in enquiries) {
      if (enquiry.id == id) return enquiry;
    }
    return null;
  }

  Future<List<Enquiry>> findByEntryId(String entryId) async {
    final enquiries = await getAll();
    return enquiries.where((e) => e.entryId == entryId).toList();
  }

  Future<void> insert(Enquiry enquiry) async {
    final enquiries = await getAll();
    enquiries.add(enquiry);
    await _persist(enquiries);
  }

  Future<void> _persist(List<Enquiry> enquiries) async {
    await _store.write(
      _collection,
      enquiries.map((e) => e.toJson()).toList(),
    );
  }
}
