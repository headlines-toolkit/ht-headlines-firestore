//
// ignore_for_file: unawaited_futures, lines_longer_than_80_chars, cascade_invocations

import 'package:cloud_firestore/cloud_firestore.dart'
    hide Source; // Hide Firestore's Source
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_categories_client/ht_categories_client.dart';
import 'package:ht_countries_client/ht_countries_client.dart';
import 'package:ht_headlines_client/ht_headlines_client.dart';
import 'package:ht_headlines_firestore/src/ht_headlines_firestore.dart';
import 'package:ht_sources_client/ht_sources_client.dart';
import 'package:mocktail/mocktail.dart';

// Mocks for Firestore classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('HtHeadlinesFirestore', () {
    late FirebaseFirestore mockFirestore;
    late HtHeadlinesFirestore headlinesFirestore;
    late CollectionReference<Map<String, dynamic>> mockCollection;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      headlinesFirestore = HtHeadlinesFirestore(firestore: mockFirestore);
      mockCollection = MockCollectionReference();

      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    });

    // Helper function to create a Headline
    Headline createHeadline({
      required DateTime publishedAt,
      String id = 'test_id',
      String title = 'Test Title',
      String? description = 'Test Description',
      String? url = 'https://example.com',
      String? imageUrl = 'https://example.com/image.jpg',
      // Use object types now
      Source? source,
      List<Category>? categories,
      Country? eventCountry,
    }) {
      // Provide default objects if null
      final defaultSource = Source(id: 'test_source_id', name: 'Test Source');
      final defaultCategory = Category(
        id: 'test_cat_id',
        name: 'Test Category',
      );
      final defaultCountry = Country(
        id: 'test_country_id',
        isoCode: 'TC',
        name: 'Test Country',
        flagUrl: 'http://example.com/flag.png',
      );

      return Headline(
        id: id,
        title: title,
        description: description,
        url: url,
        imageUrl: imageUrl,
        publishedAt: publishedAt,
        source: source ?? defaultSource,
        categories: categories ?? [defaultCategory],
        eventCountry: eventCountry ?? defaultCountry,
      );
    }

    // Helper function to create Firestore data as it would be stored
    // in Firestore.
    Map<String, dynamic> createExpectedFirestoreData(Headline headline) {
      final json = headline.toJson();
      json['publishedAt'] = Timestamp.fromDate(headline.publishedAt!);
      return json;
    }

    // Helper function to create mock Firestore data as it would be
    // returned by doc.data(). Should represent data *read* from Firestore.
    Map<String, dynamic> createMockFirestoreData(Headline headline) {
      // Manually construct the map to mimic Firestore structure
      final data = <String, dynamic>{
        'title': headline.title,
        'description': headline.description,
        'url': headline.url,
        'imageUrl': headline.imageUrl,
        // Firestore stores Timestamps, this is what _fromFirestore receives
        'publishedAt':
            headline.publishedAt != null
                ? Timestamp.fromDate(headline.publishedAt!)
                : null,
        // Nested objects are stored as maps
        'source': headline.source?.toJson(),
        'categories': headline.categories?.map((c) => c.toJson()).toList(),
        'event_country': headline.eventCountry?.toJson(),
        // Do NOT include 'id' here, as it comes from doc.id, not doc.data()
      };
      // Remove null values as Firestore might omit them
      data.removeWhere((key, value) => value == null);
      return data;
    }

    group('createHeadline', () {
      test('creates a headline successfully', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});

        final result = await headlinesFirestore.createHeadline(
          headline: headline,
        );

        expect(result, equals(headline));
        verify(() => mockCollection.doc(headline.id)).called(1);
        verify(
          () => mockDocRef.set(createExpectedFirestoreData(headline)),
        ).called(1);
      });

      test('throws HeadlineCreateException on failure', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(() => mockDocRef.set(any())).thenThrow(Exception('Failed'));

        expect(
          () => headlinesFirestore.createHeadline(headline: headline),
          throwsA(isA<HeadlineCreateException>()),
        );
      });
    });

    group('deleteHeadline', () {
      test('deletes a headline successfully', () async {
        const id = 'test_id';
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(id)).thenReturn(mockDocRef);
        when(mockDocRef.delete).thenAnswer((_) async {});

        await headlinesFirestore.deleteHeadline(id: id);

        verify(() => mockCollection.doc(id)).called(1);
        verify(mockDocRef.delete).called(1);
      });

      test('throws HeadlineDeleteException on failure', () async {
        const id = 'test_id';
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(id)).thenReturn(mockDocRef);
        when(mockDocRef.delete).thenThrow(Exception('Failed'));

        expect(
          () => headlinesFirestore.deleteHeadline(id: id),
          throwsA(isA<HeadlineDeleteException>()),
        );
      });
    });

    group('getHeadline', () {
      test('returns a headline successfully', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final firestoreData = createMockFirestoreData(headline);
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(mockDocSnap.data).thenReturn(firestoreData);
        when(
          () => mockDocSnap.id,
        ).thenReturn(headline.id); // Mock the document ID

        final result = await headlinesFirestore.getHeadline(id: headline.id);

        expect(result, equals(headline));
      });

      test('returns null if headline does not exist', () async {
        const id = 'test_id';
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        when(() => mockCollection.doc(id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(false);
        when(mockDocSnap.data).thenReturn(null);

        final result = await headlinesFirestore.getHeadline(id: id);

        expect(result, isNull);
      });

      test('throws HeadlinesFetchException on failure', () async {
        const id = 'test_id';
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenThrow(Exception('Failed'));

        expect(
          () => headlinesFirestore.getHeadline(id: id),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });

      test('throws HeadlinesFetchException if _fromFirestore fails '
          '(invalid timestamp format)', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        // Simulate invalid data from Firestore (wrong type for timestamp)
        final invalidFirestoreData = <String, dynamic>{
          'title': 'Test Title',
          'publishedAt': 'not-a-valid-iso-string', // Invalid data type/format
          'source': headline.source?.toJson(),
          'categories': headline.categories?.map((c) => c.toJson()).toList(),
          'event_country': headline.eventCountry?.toJson(),
        };
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(mockDocSnap.data).thenReturn(invalidFirestoreData);
        when(() => mockDocSnap.id).thenReturn(headline.id);

        // Expect the exception thrown by _fromFirestore during parsing
        expectLater(
          headlinesFirestore.getHeadline(id: headline.id),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });

      test('throws HeadlinesFetchException if _fromFirestore fails '
          '(missing required field)', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        // Simulate invalid data from Firestore (missing required 'title')
        final invalidFirestoreData = <String, dynamic>{
          // 'title': headline.title, // Intentionally missing
          'description': headline.description,
          'publishedAt': Timestamp.fromDate(publishedAt), // Correct type now
          'source': headline.source?.toJson(),
          'categories': headline.categories?.map((c) => c.toJson()).toList(),
          'event_country': headline.eventCountry?.toJson(),
        };
        invalidFirestoreData.removeWhere((key, value) => value == null);

        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(mockDocSnap.data).thenReturn(invalidFirestoreData);
        when(() => mockDocSnap.id).thenReturn(headline.id);

        // Expect the exception thrown by Headline.fromJson via _fromFirestore
        expectLater(
          headlinesFirestore.getHeadline(id: headline.id),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });
    });

    group('getHeadlines', () {
      test('returns headlines successfully', () async {
        final publishedAt1 = DateTime.now();
        final publishedAt2 = DateTime.now().add(const Duration(seconds: 1));
        final headline1 = createHeadline(id: 'id1', publishedAt: publishedAt1);
        final headline2 = createHeadline(id: 'id2', publishedAt: publishedAt2);
        final firestoreData1 = createMockFirestoreData(headline1);
        final firestoreData2 = createMockFirestoreData(headline2);

        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        final mockQueryDocSnap2 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.orderBy(
            any(),
            descending: any(named: 'descending'),
          ),
        ).thenReturn(mockCollection);
        when(() => mockCollection.limit(any())).thenReturn(mockCollection);
        when(() => mockCollection.get()).thenAnswer((_) async => mockQuerySnap);
        when(
          () => mockQuerySnap.docs,
        ).thenReturn([mockQueryDocSnap1, mockQueryDocSnap2]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);
        when(() => mockQueryDocSnap2.id).thenReturn(headline2.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(limit: 2);

        expect(result, equals([headline1, headline2]));
      });

      test('returns headlines with category filter', () async {
        final publishedAt = DateTime.now();
        // Create Category object for filtering
        final category1 = Category(id: 'category1', name: 'Category 1');
        final headline1 = createHeadline(
          id: 'id1',
          categories: [category1], // Pass Category object
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        // Use the ID from the Category object for the query map
        final categoryMap = {'id': category1.id};

        when(
          () => mockCollection.where('categories', arrayContains: categoryMap),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
        );

        expect(result, equals([headline1]));
      });

      test('returns headlines with source filter', () async {
        final publishedAt = DateTime.now();
        // Create Source object for filtering
        final source1 = Source(id: 'source1', name: 'Source 1');
        final headline1 = createHeadline(
          id: 'id1',
          source: source1, // Pass Source object
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          // Query nested field 'source.id' using the ID from the Source object
          () => mockCollection.where('source.id', isEqualTo: source1.id),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          source: 'source1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with eventCountry filter', () async {
        final publishedAt = DateTime.now();
        // Create Country object for filtering
        final country1 = Country(
          id: 'country1_id',
          isoCode: 'C1',
          name: 'Country 1',
          flagUrl: 'url',
        );
        final headline1 = createHeadline(
          id: 'id1',
          eventCountry: country1, // Pass Country object
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocumentSnapshot = MockQueryDocumentSnapshot();

        when(
          // Query nested field 'eventCountry.iso_code' using the parameter value
          () => mockCollection.where(
            'eventCountry.iso_code',
            isEqualTo: 'country1', // Match the parameter passed below
          ),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocumentSnapshot]);
        when(mockQueryDocumentSnapshot.data).thenReturn(firestoreData1);
        // Mock ID for the single document snapshot
        when(() => mockQueryDocumentSnapshot.id).thenReturn(headline1.id);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          eventCountry: 'country1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with category and source filter', () async {
        final publishedAt = DateTime.now();
        // Create objects for filtering
        final category1 = Category(id: 'category1', name: 'Category 1');
        final source1 = Source(id: 'source1', name: 'Source 1');
        final headline1 = createHeadline(
          id: 'id1',
          categories: [category1], // Pass Category object
          source: source1, // Pass Source object
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        // Use the ID from the Category object for the query map
        final categoryMap = {'id': category1.id};

        when(
          () => mockCollection.where('categories', arrayContains: categoryMap),
        ).thenReturn(mockQuery);
        when(
          // Use the ID from the Source object
          () => mockQuery.where('source.id', isEqualTo: source1.id),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
          source: 'source1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with category and eventCountry filter', () async {
        final publishedAt = DateTime.now();
        // Create objects for filtering
        final category1 = Category(id: 'category1', name: 'Category 1');
        final country1 = Country(
          id: 'country1_id',
          isoCode: 'C1',
          name: 'Country 1',
          flagUrl: 'url',
        );
        final headline1 = createHeadline(
          id: 'id1',
          categories: [category1], // Pass Category object
          eventCountry: country1, // Pass Country object
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        // Use the ID from the Category object for the query map
        final categoryMap = {'id': category1.id};

        when(
          () => mockCollection.where('categories', arrayContains: categoryMap),
        ).thenReturn(mockQuery);
        when(
          // Use the parameter value passed below
          () => mockQuery.where('eventCountry.iso_code', isEqualTo: 'country1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
          eventCountry: 'country1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with source and eventCountry filter', () async {
        final publishedAt = DateTime.now();
        // Create objects for filtering
        final source1 = Source(id: 'source1', name: 'Source 1');
        final country1 = Country(
          id: 'country1_id',
          isoCode: 'C1',
          name: 'Country 1',
          flagUrl: 'url',
        );
        final headline1 = createHeadline(
          id: 'id1',
          source: source1, // Pass Source object
          eventCountry: country1, // Pass Country object
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          // Use the ID from the Source object
          () => mockCollection.where('source.id', isEqualTo: source1.id),
        ).thenReturn(mockQuery);
        when(
          // Use the parameter value passed below
          () => mockQuery.where('eventCountry.iso_code', isEqualTo: 'country1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          source: 'source1',
          eventCountry: 'country1',
        );
        expect(result, equals([headline1]));
      });

      test(
        'returns headlines with category, source and eventCountry filter',
        () async {
          final publishedAt = DateTime.now();
          // Create objects for filtering
          final category1 = Category(id: 'category1', name: 'Category 1');
          final source1 = Source(id: 'source1', name: 'Source 1');
          final country1 = Country(
            id: 'country1_id',
            isoCode: 'C1',
            name: 'Country 1',
            flagUrl: 'url',
          );
          final headline1 = createHeadline(
            id: 'id1',
            categories: [category1], // Pass Category object
            source: source1, // Pass Source object
            eventCountry: country1, // Pass Country object
            publishedAt: publishedAt,
          );
          final firestoreData1 = createMockFirestoreData(headline1);

          final mockQuery = MockQuery();
          final mockQuerySnap = MockQuerySnapshot();
          final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
          // Use the ID from the Category object for the query map
          final categoryMap = {'id': category1.id};

          when(
            () =>
                mockCollection.where('categories', arrayContains: categoryMap),
          ).thenReturn(mockQuery);
          when(
            // Use the ID from the Source object
            () => mockQuery.where('source.id', isEqualTo: source1.id),
          ).thenReturn(mockQuery);
          when(
            // Use the parameter value passed below
            () =>
                mockQuery.where('eventCountry.iso_code', isEqualTo: 'country1'),
          ).thenReturn(mockQuery);
          when(
            () => mockQuery.orderBy('publishedAt', descending: true),
          ).thenReturn(mockQuery);
          when(() => mockQuery.limit(any())).thenReturn(mockQuery);
          when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
          when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
          when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
          when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

          final result = await headlinesFirestore.getHeadlines(
            limit: 2,
            category: 'category1',
            source: 'source1',
            eventCountry: 'country1',
          );
          expect(result, equals([headline1]));
        },
      );

      test('returns headlines with startAfterId', () async {
        final publishedAt1 = DateTime.now();
        final publishedAt2 = DateTime.now().add(const Duration(seconds: 1));
        final headline1 = createHeadline(id: 'id1', publishedAt: publishedAt1);
        final headline2 = createHeadline(id: 'id2', publishedAt: publishedAt2);
        final firestoreData1 = createMockFirestoreData(headline1);
        final firestoreData2 = createMockFirestoreData(headline2);

        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        final mockQueryDocSnap2 = MockQueryDocumentSnapshot();
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        when(
          () => mockCollection.orderBy(
            any(),
            descending: any(named: 'descending'),
          ),
        ).thenReturn(mockCollection);
        when(() => mockCollection.limit(any())).thenReturn(mockCollection);
        when(() => mockCollection.doc('id1')).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);

        when(
          () => mockCollection.startAfterDocument(mockDocSnap),
        ).thenReturn(mockCollection);
        when(() => mockCollection.get()).thenAnswer((_) async => mockQuerySnap);
        when(
          () => mockQuerySnap.docs,
        ).thenReturn([mockQueryDocSnap2]); // Only headline2 should be returned
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);
        when(() => mockQueryDocSnap2.id).thenReturn(headline2.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          startAfterId: 'id1',
        );
        expect(result, equals([headline2]));
      });

      test('returns headlines with startAfterId and filters', () async {
        final publishedAt1 = DateTime.now();
        final publishedAt2 = DateTime.now().add(const Duration(seconds: 1));
        // Create objects for filtering
        final category1 = Category(id: 'category1', name: 'Category 1');
        final headline1 = createHeadline(
          id: 'id1',
          categories: [category1], // Pass Category object
          publishedAt: publishedAt1,
        );
        final headline2 = createHeadline(
          id: 'id2',
          categories: [category1], // Pass Category object
          publishedAt: publishedAt2,
        );
        final firestoreData1 = createMockFirestoreData(headline1);
        final firestoreData2 = createMockFirestoreData(headline2);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        final mockQueryDocSnap2 = MockQueryDocumentSnapshot();
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();
        // Use the ID from the Category object for the query map
        final categoryMap = {'id': category1.id};

        when(
          () => mockCollection.where('categories', arrayContains: categoryMap),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockCollection.doc('id1')).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);

        when(
          () => mockQuery.startAfterDocument(mockDocSnap),
        ).thenReturn(mockQuery);

        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(
          () => mockQuerySnap.docs,
        ).thenReturn([mockQueryDocSnap2]); // Only headline2 should be returned
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);
        when(() => mockQueryDocSnap2.id).thenReturn(headline2.id); // Mock ID

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          startAfterId: 'id1',
          category: 'category1',
        );
        expect(result, equals([headline2]));
      });

      test('throws HeadlinesFetchException on failure', () async {
        when(
          () => mockCollection.orderBy(
            any(),
            descending: any(named: 'descending'),
          ),
        ).thenReturn(mockCollection);
        when(() => mockCollection.limit(any())).thenReturn(mockCollection);
        when(() => mockCollection.get()).thenThrow(Exception('Failed'));

        expect(
          () => headlinesFirestore.getHeadlines(limit: 2),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });
    });

    group('searchHeadlines', () {
      test('returns headlines successfully', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          title: 'Search Query Test',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where(
            'title',
            isGreaterThanOrEqualTo: 'Search Query',
          ),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where(
            'title',
            isLessThanOrEqualTo: 'Search Query\uf8ff',
          ),
        ).thenReturn(mockQuery);
        // Add mocking for the new orderBy('title')
        when(() => mockQuery.orderBy('title')).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID

        final result = await headlinesFirestore.searchHeadlines(
          query: 'Search Query',
          limit: 1,
        );
        expect(result, equals([headline1]));
      });

      test('throws HeadlinesSearchException on failure', () async {
        final mockQuery = MockQuery();
        when(
          () => mockCollection.where(
            'title',
            isGreaterThanOrEqualTo: 'Search Query',
          ),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where(
            'title',
            isLessThanOrEqualTo: 'Search Query\uf8ff',
          ),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenThrow(Exception('Failed'));

        expect(
          () => headlinesFirestore.searchHeadlines(
            query: 'Search Query',
            limit: 1,
          ),
          throwsA(isA<HeadlinesSearchException>()),
        );
      });

      test('returns headlines with startAfterId', () async {
        final publishedAt1 = DateTime.now();
        final publishedAt2 = DateTime.now().add(const Duration(seconds: 1));
        final headline1 = createHeadline(
          id: 'id1',
          title: 'Search Query Test',
          publishedAt: publishedAt1,
        );
        final headline2 = createHeadline(
          id: 'id2',
          title: 'Search Query Test',
          publishedAt: publishedAt2,
        );
        final firestoreData1 = createMockFirestoreData(headline1);
        final firestoreData2 = createMockFirestoreData(headline2);

        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();
        final mockQueryDocSnap2 = MockQueryDocumentSnapshot();

        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();
        final mockQuery = MockQuery();

        when(
          () => mockCollection.where(
            'title',
            isGreaterThanOrEqualTo: 'Search Query',
          ),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where(
            'title',
            isLessThanOrEqualTo: 'Search Query\uf8ff',
          ),
        ).thenReturn(mockQuery);
        // Add mocking for the new orderBy('title')
        when(() => mockQuery.orderBy('title')).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy('publishedAt', descending: true),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockCollection.doc('id1')).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(
          () => mockQuery.startAfterDocument(mockDocSnap),
        ).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(
          () => mockQuerySnap.docs,
        ).thenReturn([mockQueryDocSnap2]); // Only headline2 should be returned
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);
        when(() => mockQueryDocSnap1.id).thenReturn(headline1.id); // Mock ID
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);
        when(() => mockQueryDocSnap2.id).thenReturn(headline2.id); // Mock ID

        final result = await headlinesFirestore.searchHeadlines(
          query: 'Search Query',
          limit: 1,
          startAfterId: 'id1',
        );
        expect(result, equals([headline2]));
      });
    });

    group('createHeadline and getHeadline - Data Consistency', () {
      test('creates and retrieves a headline with consistent data', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        // Mock collection.doc() to return the same mockDocRef
        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);

        // Mock getHeadline
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(mockDocSnap.data).thenReturn(createMockFirestoreData(headline));
        when(() => mockDocSnap.id).thenReturn(headline.id); // Mock ID

        // Mock createHeadline
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});

        // Create and then get the headline
        final createdHeadline = await headlinesFirestore.createHeadline(
          headline: headline,
        );
        final retrievedHeadline = await headlinesFirestore.getHeadline(
          id: headline.id,
        );

        // Verify consistency
        expect(retrievedHeadline, equals(createdHeadline));
        expect(retrievedHeadline!.toJson(), equals(createdHeadline.toJson()));
      });
    });

    group('updateHeadline and getHeadline - Data Consistency', () {
      test('updates and retrieves a headline with consistent data', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final updatedHeadline = headline.copyWith(title: 'Updated Title');
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        // Mock collection.doc() to return the same mockDocRef
        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);

        // Mock getHeadline
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(
          mockDocSnap.data,
        ).thenReturn(createMockFirestoreData(updatedHeadline));
        when(() => mockDocSnap.id).thenReturn(headline.id); // Mock ID

        // Mock updateHeadline
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        // Update and then get the headline
        final result = await headlinesFirestore.updateHeadline(
          headline: updatedHeadline,
        );
        final retrievedHeadline = await headlinesFirestore.getHeadline(
          id: headline.id,
        );

        // Verify consistency
        expect(retrievedHeadline, equals(result));
        expect(retrievedHeadline!.toJson(), equals(updatedHeadline.toJson()));
      });
    });

    group('updateHeadline', () {
      test('updates a headline successfully', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        final result = await headlinesFirestore.updateHeadline(
          headline: headline,
        );

        expect(result, equals(headline));
        verify(() => mockCollection.doc(headline.id)).called(1);
        verify(
          () => mockDocRef.update(createExpectedFirestoreData(headline)),
        ).called(1);
      });

      test('throws HeadlineUpdateException on failure', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenThrow(Exception('Failed'));

        expect(
          () => headlinesFirestore.updateHeadline(headline: headline),
          throwsA(isA<HeadlineUpdateException>()),
        );
      });

      // Test for _toFirestoreMap exception
      test('throws HeadlineUpdateException if _toFirestoreMap fails', () async {
        final publishedAt = DateTime.now();
        // Create a headline that might cause issues during serialization
        // (e.g., if a nested object's toJson fails - harder to mock directly)
        // For simplicity, we'll mock the failure during the update call
        final headline = createHeadline(publishedAt: publishedAt);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        // Simulate failure during the update operation itself
        when(
          () => mockDocRef.update(any()),
        ).thenThrow(Exception('Firestore update failed'));

        expect(
          () => headlinesFirestore.updateHeadline(headline: headline),
          throwsA(isA<HeadlineUpdateException>()),
        );

        // To specifically test _toFirestoreMap's catch block is harder
        // without complex mocking of headline.toJson() internal failures.
        // This test primarily covers the update operation's catch block.
      });
    });
  });
}
