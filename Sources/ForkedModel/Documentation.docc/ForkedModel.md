# ForkedModel

Create mergeable data models using Swift value types.

## Overview

ForkedModel provides a simple way to define data models using Swift value types (_ie_ structs), which can be safely merged when concurrent changes occur. Attaching the `@ForkedModel` macro to a `struct`, you can create a data model that can handle property-wise merging with sophisticated algorithms.

A mergeable model is useful for handling concurrent changes to data within your app, between processes (_eg_ extensions), and even between devices if you are syncing with iCloud. Adopting `@ForkedModel` takes very little effort, has very little risk since your model is comprised of standard structs, and prepares your app for whatever data concurrency challenges may arise.

## Creating a Basic Model

You create a mergeable model using the `@ForkedModel` macro:

```swift
@ForkedModel 
struct User {
    var name: String = ""
    var age: Int = 0
}
```

The attributes in this model will be merged using a "most recent wins" strategy — if both forks modify the same property, the most recent change will be kept.

Note that equatable properties will be merged in a property-wise fashion. If the `name` property is modified in one fork, and the `age` property is modified in another, the most recent of each property will be kept when merging. This is different to just choosing the most recent value of the struct, which does not consider how the individual properties have changed.

> The `@ForkedModel` macro generates a standard Swift struct with an extension that conforms to `Mergeable`. There is no runtime overhead or magic - just pure Swift value types with some helper functions to facilitate merging. The generated struct can be used the same as any other struct, including adding `Codable` conformance to save or work with a web service.

## Using `@Merged` Properties

The `@Merged` macro works alongside `@ForkedModel`, specifying how specific properties should be merged when conflicts arise. By default, `@Merged` will choose an appropriate merging strategy based on the property type:

```swift
@ForkedModel
struct Note {
    @Merged var title: String = ""             // Uses a text merging algorithm
    @Merged var tags: Set<String> = []         // Uses a special set merging algorithm
    @Merged var pages: [String] = []           // Uses array merging algorithm
    @Merged var metadata: [String:Int] = [:]   // Uses dictionary merging
}
```

The algorithms for merging these properties are quite sophisticated. They utilize state-of-the-art algorithms known as Conflict-free Replicated Data Types (CRDTs). These algorithms aim to generate a result that is consistent with the expectations of people, rather than just convenient to program.

### Default Merging Strategies

When using the `@Merged` macro, each type has a default merging algorithm, but you can also specify a different algorithm. The default merging strategies are:

- `String` properties use `.textMerge`
- `Array` properties use `.arrayMerge`
- `Set` properties use `.setMerge`
- `Dictionary` properties use `.dictionaryMerge`
- Types that conform to `Mergeable` use their own merging implementation

## Customizing Merge Behavior

You can explicitly specify which merging algorithm to use with the `using:` parameter on `@Merged`:

```swift
@ForkedModel
struct Document {
    // Explicitly use text merging for string content
    @Merged(using: .textMerge) var content: String = ""
    
    // Use array merging for ordered lists
    @Merged(using: .arrayMerge) var sections: [String] = []
    
    // Special merge for arrays of identifiable items
    @Merged(using: .arrayOfIdentifiableMerge) var comments: [Comment] = []
    
    // Use set merging for unordered collections
    @Merged(using: .setMerge) var categories: Set<String> = []
    
    // Use dictionary merging for key-value data
    @Merged(using: .dictionaryMerge) var metadata: [String:String] = [:]
}
```

### Available Merge Strategies

- `.textMerge`: Intelligently merges text changes in a way people would expect
- `.arrayMerge`: Merges arrays by combining elements in an expected fashion
- `.arrayOfIdentifiableMerge`: Merges arrays of items conforming to `Identifiable`, ensuring uniqueness of IDs
- `.setMerge`: Merges sets using set operations, handling conflicts in a way that is consistent with expections
- `.dictionaryMerge`: Merges dictionaries by combining key-value pairs, handling conflicts in a way that is consistent with human expectations

## Working with Optional Properties

ForkedModel handles optional properties seamlessly:

```swift
@ForkedModel
struct NoteWithOptionals {
    var title: String = ""
    @Merged var description: String?
    @Merged(using: .arrayOfIdentifiableMerge) var items: [NoteItem]?
}
```

## Custom Mergeable Types

You can use custom types that conform to `Mergeable` with `@Merged`:

```swift
struct Counter: Mergeable {
    var value: Int = 0
    
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        Counter(value: self.value + other.value - commonAncestor.value)
    }
}

@ForkedModel
struct Document {
    @Merged var wordCount: Counter = Counter()
}
```

## Recursive Merging

Many of the merge algorithms will recursively apply merging to their contained elements if those elements conform to `Mergeable`. This allows for sophisticated nested data structures:

```swift
@ForkedModel
struct Comment: Identifiable {
    var id: UUID = UUID()
    @Merged var text: String = ""
}

@ForkedModel
struct BlogPost {
    @Merged var title: String = ""
    @Merged(using: .arrayOfIdentifiableMerge) var comments: [Comment] = []
}
```

In this example, when comments are merged:

1. `.arrayOfIdentifiableMerge` handles the array of comments
2. It ensures that when multiple comments with the same ID are encountered, they are properly merged
3. Inside each `Comment`, the `text` is merged using text merging

The same principle applies to dictionary values:

```swift
@ForkedModel
struct Document {
    @Merged(using: .dictionaryMerge) var sections: [String: Comment] = [:]
}
```

When merging the dictionary, if the values for a given key are `Mergeable`, they will be merged recursively rather than just taking the most recent value.

## Important Notes

- All non-optional stored properties must have default values
- The `@ForkedModel` macro automatically makes your type conform to `Mergeable`
- Properties without `@Merged` will use a "most recent wins" strategy, in a property-wise fashion
- Non-equatable properties without `@Merged` will use a "most recent wins" strategy for the entire struct
- The merging strategy is determined at compile time and cannot be changed at runtime
