This package is a Firestore implementation of the `ht_headlines_client` package, providing a concrete way to interact with headlines data stored in Firebase Firestore. It offers functionalities to create, read, update, delete, and search headline data within a Firestore database, with support for filtering and pagination.

## Features

This package provides a Firestore implementation for the `ht_headlines_client`. It allows you to use Firebase Firestore as the backend for storing and retrieving headline data.

*   **Create Headline:** Adds a new headline to the Firestore database. The `Headline` model includes `Source`, `Category` (single), and `Country` objects.
*   **Read Headline:** Retrieves a specific headline by its ID from Firestore, populating the `Source`, `Category`, and `Country` objects.
*   **Read Headlines:** Fetches headlines from the Firestore database. Supports limiting, pagination (`startAfterId`), and filtering by lists of `Category`, `Source`, or `Country` objects.
    *   **Filtering Logic:**
        *   Providing a list (e.g., `categories: [catA, catB]`) filters for headlines where the corresponding field matches **any** item in the list (OR logic within the list).
        *   Providing multiple lists (e.g., `categories: [catA]`, `sources: [srcX]`) combines filters with **AND** logic.
        *   Uses Firestore `whereIn` queries internally, comparing against the JSON map representation of the filter objects *without* their `id` field.
*   **Update Headline:** Modifies an existing headline in Firestore, using `Source`, `Category`, and `Country` objects.
*   **Delete Headline:** Removes a headline from Firestore.
*   **Search Headlines:** Queries Firestore for headlines based on a search term (performs a basic full-text search simulation on the title field). Supports limiting and pagination.

## Getting started

To use this package, you need to have Firebase set up in your Flutter project and Firestore initialized.

Add `ht_headlines_firestore` as a dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  ht_headlines_firestore:
    git:
      url: https://github.com/headlines-toolkit/ht-headlines-firestore.git
      ref: main
```

Then, import the package in your Dart code:

```dart
import 'package:ht_headlines_firestore/ht_headlines_firestore.dart';
```

Initialize the client with a `FirebaseFirestore` instance:

```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);
```

## Usage

Here are a few examples of how to use the `HtHeadlinesFirestore`:

**Create a headline:**

```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);

// Assuming you have instances of Source, Category, and Country
final source = Source(id: 'tech_news_id', name: 'Tech News');
final category = Category(id: 'tech_cat_id', name: 'Technology');
final country = Country(id: 'us_id', isoCode: 'US', name: 'United States', flagUrl: '...');

final headline = Headline(
    id: 'unique_headline_id',
    title: 'Example Headline',
    description: 'This is an example headline.',
    publishedAt: DateTime.now(),
    source: source,
    category: category, // Headline uses a single category
    eventCountry: country,
  );
try {
    final createdHeadline = await firestoreClient.createHeadline(headline: headline);
    print('Created headline ID: ${createdHeadline.id}');
} on HeadlineCreateException catch (e) {
    print(e.message);
}
```

**Get a headline:**

```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);
final headlineId = 'unique_headline_id';
try {
  final headline = await firestoreClient.getHeadline(id: headlineId);
  if (headline != null) {
    print('Headline title: ${headline.title}');
  } else {
    print('Headline not found.');
  }
} on HeadlinesFetchException catch (e) {
  print(e.message);
}
```

**Get headlines with filtering and pagination:**

```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);

// Assuming you have instances of Category, Source, and Country objects
final techCategory = Category(id: 'tech_cat_id', name: 'Technology');
final newsSource = Source(id: 'news_src_id', name: 'News Source');
final usCountry = Country(id: 'us_id', isoCode: 'US', name: 'United States', flagUrl: '...');

try {
    // Pass lists of objects for filtering.
    // OR logic applies within each list, AND logic applies between lists.
    final headlines = await firestoreClient.getHeadlines(
        limit: 10,
        categories: [techCategory], // Filter by Category objects
        sources: [newsSource],     // Filter by Source objects
        // eventCountries: [usCountry], // Optionally filter by Country objects
        startAfterId: 'last_headline_id', // For pagination
    );
    print('Found ${headlines.length} headlines.');
    for (final headline in headlines) {
        print('- ${headline.title}');
    }
} on HeadlinesFetchException catch (e) {
    print(e.message);
}
```

**Update a headline:**
```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);

// Assuming you have instances of Source, Category, and Country
final updatedSource = Source(id: 'updated_source_id', name: 'Updated Source');
final updatedCategory = Category(id: 'updated_cat_id', name: 'Updated Category');
final updatedCountry = Country(id: 'gb_id', isoCode: 'GB', name: 'United Kingdom', flagUrl: '...');

final headlineToUpdate = Headline(
    id: 'unique_headline_id',
    title: 'Updated Headline Title',
    description: 'This is an updated headline description.',
    publishedAt: DateTime.now(),
    source: updatedSource,
    category: updatedCategory, // Headline uses a single category
    eventCountry: updatedCountry,
  );
try {
  final updatedHeadline =
      await firestoreClient.updateHeadline(headline: headlineToUpdate);
  print('Updated headline title: ${updatedHeadline.title}');
} on HeadlineUpdateException catch (e) {
  print(e.message);
}
```

**Delete a headline:**
```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);
final headlineIdToDelete = 'unique_headline_id';

try {
  await firestoreClient.deleteHeadline(id: headlineIdToDelete);
  print('Headline deleted successfully.');
} on HeadlineDeleteException catch (e) {
  print(e.message);
}
```

**Search headlines:**

```dart
final firestore = FirebaseFirestore.instance;
final firestoreClient = HtHeadlinesFirestore(firestore: firestore);
final searchQuery = 'example';
try {
  final headlines = await firestoreClient.searchHeadlines(
    query: searchQuery,
    limit: 10,
    startAfterId: 'last_headline_id', // For pagination
    );
  print('Found ${headlines.length} headlines matching "$searchQuery".');
  for (final headline in headlines) {
    print('- ${headline.title}');
  }
} on HeadlinesSearchException catch (e) {
    print(e.message);
}
```

**Issues**

If you encounter any issues or have suggestions, please file them on the [issue tracker](https://github.com/headlines-toolkit/ht-headlines-firestore).
