//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

// Hide Source from cloud_firestore to avoid conflict with ht_sources_client
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:ht_categories_client/ht_categories_client.dart';
import 'package:ht_countries_client/ht_countries_client.dart';
import 'package:ht_headlines_client/ht_headlines_client.dart';
import 'package:ht_sources_client/ht_sources_client.dart';

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
    List<Category>? categories,
    List<Source>? sources,
    List<Country>? eventCountries,
  }) async {
    try {
      // Start with the base query for the headlines collection.
      Query<Map<String, dynamic>> query = _firestore.collection(
        _collectionName,
      );

      // Apply category filter:
      // If categories are provided, filter headlines where the 'category' field
      // matches *any* of the provided categories (OR logic within the list).
      // Firestore's 'whereIn' requires the exact map representation.
      if (categories != null && categories.isNotEmpty) {
        // Note: Firestore 'whereIn' queries are limited to 10 items per query.
        // If more than 10 categories are needed, multiple queries might be
        // required, or the data model might need adjustment (e.g., storing
        // category IDs in an array field). For now, assuming <= 10.
        query = query.where(
          'category', // The field name in Firestore for the single category
          // Map categories to their JSON representation *without* the 'id' field
          // to match the structure stored in Firestore documents.
          whereIn:
              categories.map((c) {
                final json = c.toJson()..remove('id');
                return json;
              }).toList(),
        );
      }

      // Apply source filter:
      // If sources are provided, filter headlines where the 'source' field
      // matches *any* of the provided sources (OR logic within the list).
      // This acts as an AND condition with the category filter if both are present.
      if (sources != null && sources.isNotEmpty) {
        // Similar 'whereIn' limitation applies (max 10 items).
        query = query.where(
          'source', // The field name in Firestore for the single source
          // Map sources to their JSON representation *without* the 'id' field.
          whereIn:
              sources.map((s) {
                final json = s.toJson()..remove('id');
                return json;
              }).toList(),
        );
      }

      // Apply event country filter:
      // If eventCountries are provided, filter headlines where the 'event_country'
      // field matches *any* of the provided countries (OR logic within the list).
      // This acts as an AND condition with other filters if present.
      if (eventCountries != null && eventCountries.isNotEmpty) {
        // Similar 'whereIn' limitation applies (max 10 items).
        query = query.where(
          'event_country', // The field name in Firestore
          // Map countries to their JSON representation *without* the 'id' field.
          whereIn:
              eventCountries.map((c) {
                final json = c.toJson()..remove('id');
                return json;
              }).toList(),
        );
      }

      // Apply limit if specified.
      if (limit != null) {
        query = query.limit(limit);
      }

      // Order results by publication date, newest first.
      // Note: Firestore requires the first orderBy field to match the field
      // used in inequality filters (like startAfterDocument implicitly uses).
      // If complex filtering/sorting is needed, indexing might be required.
      // For 'whereIn', Firestore might require composite indexes if combined
      // with other range/inequality filters or multiple orderBy clauses.
      // We are ordering by 'publishedAt' which is common.
      query = query.orderBy('publishedAt', descending: true);

      // Handle pagination: Start fetching after the specified document ID.
      if (startAfterId != null) {
        // Fetch the document snapshot to use with startAfterDocument.
        final startAfterDoc =
            await _firestore
                .collection(_collectionName)
                .doc(startAfterId)
                .get();
        if (startAfterDoc.exists) {
          // Use the document snapshot for pagination.
          query = query.startAfterDocument(startAfterDoc);
        } else {
          // Handle case where startAfterId doesn't exist, maybe log or ignore.
          // For now, we proceed without pagination if the doc is not found.
          // Consider logging this scenario for debugging.
          // print('Warning: startAfterId $startAfterId not found.');
        }
      }

      // Execute the query.
      final snapshot = await query.get();

      // Convert Firestore documents to Headline objects using the helper.
      return snapshot.docs
          .map((doc) => _fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // Catch potential Firestore errors or issues during data conversion.
      // Consider more specific error handling or logging if needed.
      throw HeadlinesFetchException(
        'Failed to fetch headlines from Firestore: $e',
      );
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

      // Basic full-text search simulation using title. Firestore doesn't
      // support native full-text search, so this is a very limited
      // implementation. For real full-text search, consider Algolia,
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
        if (startAfterDoc.exists) {
          firestoreQuery = firestoreQuery.startAfterDocument(startAfterDoc);
        }
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
  /// **Important:** Removes the 'id' field from the map, as the Firestore
  /// document ID serves as the canonical identifier.
  Map<String, dynamic> _toFirestoreMap(Headline headline) {
    try {
      // Generate the JSON map from the Headline object.
      final json =
          headline.toJson()
            // Remove the 'id' field. The Firestore document ID is used instead.
            // This ensures the document data strictly mirrors the model properties
            // *excluding* the ID.
            ..remove('id');

      // Convert DateTime back to Timestamp for publishedAt if present.
      // Firestore requires Timestamps for date/time fields for proper querying.
      final publishedAtValue = json['publishedAt'];
      if (publishedAtValue is String) {
        // If toJson produced an ISO string, parse it and convert to Timestamp.
        try {
          json['publishedAt'] = Timestamp.fromDate(
            DateTime.parse(publishedAtValue).toUtc(),
          );
        } catch (_) {
          // If parsing fails, remove the field to avoid storing invalid data.
          // Consider logging this failure.
          json.remove('publishedAt');
        }
      } else if (publishedAtValue is DateTime) {
        // If toJson somehow returned DateTime (less likely with json_serializable),
        // convert directly.
        json['publishedAt'] = Timestamp.fromDate(publishedAtValue.toUtc());
      }
      // If publishedAt is null or already a Timestamp, no action needed.

      // json_serializable with explicitToJson handles nested objects
      // (Source, Category, Country) conversion within toJson().
      return json;
    } catch (e) {
      // Catch potential errors during JSON conversion or timestamp handling.
      // Consider logging the stack trace for better debugging.
      throw HeadlineUpdateException(
        // Or Create/Update depending on context
        'Failed to convert Headline to Firestore map: $e',
      );
    }
  }
}
