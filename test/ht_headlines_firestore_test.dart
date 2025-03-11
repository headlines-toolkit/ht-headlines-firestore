import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_headlines_client/ht_headlines_client.dart';
import 'package:ht_headlines_firestore/src/ht_headlines_firestore.dart';
import 'package:mocktail/mocktail.dart';

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
      String? source = 'Test Source',
      List<String>? categories = const ['Test Category'],
      String? eventCountry = 'Test Country',
    }) {
      return Headline(
        id: id,
        title: title,
        description: description,
        url: url,
        imageUrl: imageUrl,
        publishedAt: publishedAt,
        source: source,
        categories: categories,
        eventCountry: eventCountry,
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
    // returned by doc.data().
    Map<String, dynamic> createMockFirestoreData(Headline headline) {
      final json = headline.toJson();
      json['publishedAt'] = headline.publishedAt!.toIso8601String();
      return json;
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
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);

        final result = await headlinesFirestore.getHeadlines(limit: 2);

        expect(result, equals([headline1, headline2]));
      });

      test('returns headlines with category filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          categories: ['category1'],
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('categories', arrayContains: 'category1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
        );

        expect(result, equals([headline1]));
      });

      test('returns headlines with source filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          source: 'source1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('source', isEqualTo: 'source1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          source: 'source1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with eventCountry filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          eventCountry: 'country1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocumentSnapshot = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('eventCountry', isEqualTo: 'country1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocumentSnapshot]);
        when(mockQueryDocumentSnapshot.data).thenReturn(firestoreData1);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          eventCountry: 'country1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with category and source filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          categories: ['category1'],
          source: 'source1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('categories', arrayContains: 'category1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where('source', isEqualTo: 'source1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
          source: 'source1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with category and eventCountry filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          categories: ['category1'],
          eventCountry: 'country1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('categories', arrayContains: 'category1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where('eventCountry', isEqualTo: 'country1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
          eventCountry: 'country1',
        );
        expect(result, equals([headline1]));
      });

      test('returns headlines with source and eventCountry filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          source: 'source1',
          eventCountry: 'country1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('source', isEqualTo: 'source1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where('eventCountry', isEqualTo: 'country1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

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
          final headline1 = createHeadline(
            id: 'id1',
            categories: ['category1'],
            source: 'source1',
            eventCountry: 'country1',
            publishedAt: publishedAt,
          );
          final firestoreData1 = createMockFirestoreData(headline1);

          final mockQuery = MockQuery();
          final mockQuerySnap = MockQuerySnapshot();
          final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

          when(
            () =>
                mockCollection.where('categories', arrayContains: 'category1'),
          ).thenReturn(mockQuery);
          when(
            () => mockQuery.where('source', isEqualTo: 'source1'),
          ).thenReturn(mockQuery);
          when(
            () => mockQuery.where('eventCountry', isEqualTo: 'country1'),
          ).thenReturn(mockQuery);
          when(
            () =>
                mockQuery.orderBy(any(), descending: any(named: 'descending')),
          ).thenReturn(mockQuery);
          when(() => mockQuery.limit(any())).thenReturn(mockQuery);
          when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
          when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
          when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

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
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          startAfterId: 'id1',
        );
        expect(result, equals([headline2]));
      });

      test('returns headlines with startAfterId and filters', () async {
        final publishedAt1 = DateTime.now();
        final publishedAt2 = DateTime.now().add(const Duration(seconds: 1));
        final headline1 = createHeadline(
          id: 'id1',
          categories: ['category1'],
          publishedAt: publishedAt1,
        );
        final headline2 = createHeadline(
          id: 'id2',
          categories: ['category1'],
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

        when(
          () => mockCollection.where('categories', arrayContains: 'category1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
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
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          startAfterId: 'id1',
          category: 'category1',
        );
        expect(result, equals([headline2]));
      });

      test('returns headlines with category and source filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          categories: ['category1'],
          source: 'source1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createMockFirestoreData(headline1);

        final mockQuery = MockQuery();
        final mockQuerySnap = MockQuerySnapshot();
        final mockQueryDocSnap1 = MockQueryDocumentSnapshot();

        when(
          () => mockCollection.where('categories', arrayContains: 'category1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.where('source', isEqualTo: 'source1'),
        ).thenReturn(mockQuery);
        when(
          () => mockQuery.orderBy(any(), descending: any(named: 'descending')),
        ).thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

        final result = await headlinesFirestore.getHeadlines(
          limit: 2,
          category: 'category1',
          source: 'source1',
        );
        expect(result, equals([headline1]));
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
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(mockQuery.get).thenAnswer((_) async => mockQuerySnap);
        when(() => mockQuerySnap.docs).thenReturn([mockQueryDocSnap1]);
        when(mockQueryDocSnap1.data).thenReturn(firestoreData1);

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
        when(mockQueryDocSnap2.data).thenReturn(firestoreData2);

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
    });
  });
}
