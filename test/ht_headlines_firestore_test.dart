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

    // Helper function to create Firestore data
    Map<String, dynamic> createFirestoreData(Headline headline) {
      final json = <String, dynamic>{};
      json['id'] = headline.id;
      json['title'] = headline.title;
      json['description'] = headline.description;
      json['url'] = headline.url;
      json['imageUrl'] = headline.imageUrl;
      json['publishedAt'] = Timestamp.fromDate(headline.publishedAt!);
      json['source'] = headline.source;
      json['categories'] = headline.categories;
      json['eventCountry'] = headline.eventCountry;

      return json;
    }

    group('createHeadline', () {
      test('creates a headline successfully', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final firestoreData = createFirestoreData(headline);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});

        final result = await headlinesFirestore.createHeadline(
          headline: headline,
        );

        expect(result, equals(headline));
        verify(() => mockCollection.doc(headline.id)).called(1);
        verify(() => mockDocRef.set(createFirestoreData(headline))).called(1);
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
        final firestoreData = createFirestoreData(headline);
        final mockDocRef = MockDocumentReference();
        final mockDocSnap = MockDocumentSnapshot();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(mockDocSnap.data).thenReturn(firestoreData);

        expect(
          () => headlinesFirestore.getHeadline(id: headline.id),
          throwsA(isA<HeadlinesFetchException>()),
        );
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
        final firestoreData1 = createFirestoreData(headline1);
        final firestoreData2 = createFirestoreData(headline2);

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

        expect(
          () => headlinesFirestore.getHeadlines(limit: 2),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });

      test('returns headlines with category filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          categories: ['category1'],
          publishedAt: publishedAt,
        );
        final firestoreData1 = createFirestoreData(headline1);

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

        expect(
          () =>
              headlinesFirestore.getHeadlines(limit: 2, category: 'category1'),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });

      test('returns headlines with source filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          source: 'source1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createFirestoreData(headline1);

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

        expect(
          () => headlinesFirestore.getHeadlines(limit: 2, source: 'source1'),
          throwsA(isA<HeadlinesFetchException>()),
        );
      });

      test('returns headlines with eventCountry filter', () async {
        final publishedAt = DateTime.now();
        final headline1 = createHeadline(
          id: 'id1',
          eventCountry: 'country1',
          publishedAt: publishedAt,
        );
        final firestoreData1 = createFirestoreData(headline1);

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

        expect(
          () => headlinesFirestore.getHeadlines(
            limit: 2,
            eventCountry: 'country1',
          ),
          throwsA(isA<HeadlinesFetchException>()),
        );
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
        final firestoreData1 = createFirestoreData(headline1);

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

        expect(
          () => headlinesFirestore.searchHeadlines(
            query: 'Search Query',
            limit: 1,
          ),
          throwsA(isA<HeadlinesSearchException>()),
        );
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
    });

    group('updateHeadline', () {
      test('updates a headline successfully', () async {
        final publishedAt = DateTime.now();
        final headline = createHeadline(publishedAt: publishedAt);
        final firestoreData = createFirestoreData(headline);
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc(headline.id)).thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        final result = await headlinesFirestore.updateHeadline(
          headline: headline,
        );

        expect(result, equals(headline));
        verify(() => mockCollection.doc(headline.id)).called(1);
        verify(
          () => mockDocRef.update(createFirestoreData(headline)),
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
