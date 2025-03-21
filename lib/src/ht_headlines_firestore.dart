// Advanced Dart Code Synthesis & Optimization Engine

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
    String? category,
    String? source,
    String? eventCountry,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(
        _collectionName,
      );

      if (category != null) {
        query = query.where('categories', arrayContains: category);
      }

      if (source != null) {
        query = query.where('source', isEqualTo: source);
      }

      if (eventCountry != null) {
        query = query.where('eventCountry', isEqualTo: eventCountry);
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

      if (limit != null) {
        firestoreQuery = firestoreQuery.limit(limit);
      }

      firestoreQuery = firestoreQuery.orderBy('publishedAt', descending: true);

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
  /// This method handles: 
  /// - the conversion of the `publishedAt` field from a Firestore 
  /// [Timestamp] to a [String].
  /// - assigning the correct Firestore document id to the [Headline]
  ///
  /// [data]: The Firestore document data.
  /// [id]: The document ID.
  Headline _fromFirestore(Map<String, dynamic> data, String id) {
    try {
      dynamic publishedAt = data['publishedAt'];
      if (publishedAt is Timestamp) {
        publishedAt = publishedAt.toDate().toString();
      }
      return Headline.fromJson({...data, 'publishedAt': publishedAt, 'id': id});
    } catch (e) {
      throw HeadlinesFetchException('Failed to process headline: $e');
    }
  }

  /// Converts a [Headline] object to a Firestore document data map.
  ///
  /// This method handles the conversion of the `publishedAt` field
  /// from a [String] to a Firestore [Timestamp].
  Map<String, dynamic> _toFirestoreMap(Headline headline) {
    final json = headline.toJson();
    final publishedAt = json['publishedAt'];
    if (publishedAt is String) {
      json['publishedAt'] = Timestamp.fromDate(
        DateTime.parse(publishedAt).toUtc(),
      );
    }
    return json;
  }
}
