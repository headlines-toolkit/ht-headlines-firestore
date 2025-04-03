//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_headlines_client/ht_headlines_client.dart';

/// {@template ht_headlines_firestore}
/// A Firestore implementation of the [HtHeadlinesClient].
/// {@endtemplate}
class HtHeadlinesFirestore implements HtHeadlinesClient {
  /// {@macro ht_headlines_firestore}
  HtHeadlinesFirestore({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// The collection name for headlines in Firestore.
  static const _collectionName = 'headlines';

  @override
  Future<Headline> createHeadline({required Headline headline}) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(headline.id);
      await docRef.set(_toFirestoreMap(headline));
      return headline;
    } catch (e) {
      throw HeadlineCreateException('Failed to create headline: $e');
    }
  }

  @override
  Future<void> deleteHeadline({required String id}) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      throw HeadlineDeleteException('Failed to delete headline: $e');
    }
  }

  @override
  Future<Headline?> getHeadline({required String id}) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return _fromFirestore(doc.data()!, doc.id);
      } else {
        return null;
      }
    } catch (e) {
      throw HeadlinesFetchException('Failed to fetch headline: $e');
    }
  }

  @override
  Future<List<Headline>> getHeadlines({
    int? limit,
    String? startAfterId,
    // Parameters match HtHeadlinesClient interface
    String? category,
    String? source,
    String? eventCountry,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(
        _collectionName,
      );

      // Note: Firestore's arrayContains requires an exact match for map elements.
      // Assuming 'category' parameter is the category ID.
      // Ensure the Category object stored in Firestore has an 'id' field.
      if (category != null) {
        // We need to construct the map representation of the Category
        // as it would be stored in Firestore for the arrayContains query.
        // Assuming Category.toJson() produces {'id': ..., 'name': ...} etc.
        // and we only need to match the ID for filtering.
        // A more robust solution might involve storing a separate array of IDs.
        query = query.where(
          'categories',
          arrayContains: {
            'id': category,
          }, // Query based on category ID within the map
        );
      }

      // Query nested fields using dot notation. Assuming 'source' is the source ID.
      if (source != null) {
        query = query.where('source.id', isEqualTo: source);
      }

      // Query nested fields using dot notation. Assuming 'eventCountry' is the country ISO code.
      if (eventCountry != null) {
        query = query.where('eventCountry.iso_code', isEqualTo: eventCountry);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      query = query.orderBy('publishedAt', descending: true);

      if (startAfterId != null) {
        final startAfterDoc =
            await _firestore
                .collection(_collectionName)
                .doc(startAfterId)
                .get();
        query = query.startAfterDocument(startAfterDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => _fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw HeadlinesFetchException('Failed to fetch headlines: $e');
    }
  }

  @override
  Future<List<Headline>> searchHeadlines({
    required String query,
    int? limit,
    String? startAfterId,
  }) async {
    try {
      Query<Map<String, dynamic>> firestoreQuery = _firestore.collection(
        _collectionName,
      );

      // Basic full-text search simulation using title.  Firestore doesn't
      // support native full-text search, so this is a very limited
      // implementation.  For real full-text search, consider Algolia,
      // Elasticsearch, or Typesense.
      firestoreQuery = firestoreQuery
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff');

      // Firestore requires ordering by the field used in range filters.
      // Add orderBy('title') first.
      firestoreQuery = firestoreQuery.orderBy('title');

      // Then order by publishedAt as a secondary sort.
      firestoreQuery = firestoreQuery.orderBy('publishedAt', descending: true);

      if (limit != null) {
        firestoreQuery = firestoreQuery.limit(limit);
      }

      if (startAfterId != null) {
        final startAfterDoc =
            await _firestore
                .collection(_collectionName)
                .doc(startAfterId)
                .get();
        firestoreQuery = firestoreQuery.startAfterDocument(startAfterDoc);
      }

      final snapshot = await firestoreQuery.get();
      return snapshot.docs
          .map((doc) => _fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw HeadlinesSearchException('Failed to search headlines: $e');
    }
  }

  @override
  Future<Headline> updateHeadline({required Headline headline}) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(headline.id)
          .update(_toFirestoreMap(headline));
      return headline;
    } catch (e) {
      throw HeadlineUpdateException('Failed to update headline: $e');
    }
  }

  /// Converts a Firestore document data map to a [Headline] object.
  ///
  /// Converts a Firestore document data map to a [Headline] object.
  ///
  /// Handles the conversion of Firestore Timestamps to DateTime objects
  /// for fields like `publishedAt`. It relies on `Headline.fromJson`
  /// generated by `json_serializable` to handle nested objects
  /// (`Source`, `Category`, `Country`).
  ///
  /// [data]: The Firestore document data.
  /// [id]: The document ID.
  Headline _fromFirestore(Map<String, dynamic> data, String id) {
    try {
      // Create a mutable copy to handle timestamp conversion if needed.
      final mutableData = Map<String, dynamic>.from(data);

      // Convert Timestamp to ISO 8601 String for publishedAt, which fromJson expects
      final publishedAtTimestamp = mutableData['publishedAt'];
      if (publishedAtTimestamp is Timestamp) {
        mutableData['publishedAt'] =
            publishedAtTimestamp.toDate().toIso8601String();
      } else if (publishedAtTimestamp is DateTime) {
        // Handle case where it might already be DateTime (less likely from Firestore)
        mutableData['publishedAt'] = publishedAtTimestamp.toIso8601String();
      }

      // Add the document ID to the data map before deserialization.
      mutableData['id'] = id;

      // Let Headline.fromJson handle the rest, including nested objects.
      return Headline.fromJson(mutableData);
    } catch (e) {
      // Consider logging the stack trace for better debugging.
      throw HeadlinesFetchException(
        'Failed to process headline data from Firestore: $e',
      );
    }
  }

  /// Converts a [Headline] object to a Firestore document data map.
  ///
  /// Relies on `headline.toJson()` generated by `json_serializable`
  /// (with `explicitToJson: true`) to handle nested objects correctly.
  /// Converts `DateTime` fields like `publishedAt` back to Firestore Timestamps.
  Map<String, dynamic> _toFirestoreMap(Headline headline) {
    try {
      final json = headline.toJson();

      // Convert DateTime back to Timestamp for publishedAt if present.
      final publishedAtDateTime = json['publishedAt'];
      if (publishedAtDateTime is DateTime) {
        json['publishedAt'] = Timestamp.fromDate(publishedAtDateTime.toUtc());
      } else if (publishedAtDateTime is String) {
        // Handle case where it might already be a string (less likely now)
        try {
          json['publishedAt'] = Timestamp.fromDate(
            DateTime.parse(publishedAtDateTime).toUtc(),
          );
        } catch (_) {
          // If parsing fails, maybe remove or log, depending on requirements.
          json.remove('publishedAt');
        }
      }

      // json_serializable with explicitToJson handles nested objects.
      return json;
    } catch (e) {
      // Consider logging the stack trace.
      throw HeadlineUpdateException(
        // Or Create/Update depending on context
        'Failed to convert Headline to Firestore map: $e',
      );
    }
  }
}
