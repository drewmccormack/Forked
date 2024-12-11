# Getting Started with Forked

Learn how to use Forked to manage shared data in your Swift applications.

## Overview

Forked provides a safe way to handle shared data by allowing you to create independent branches (forks) of your data that can be modified concurrently and merged later. This guide will walk you through the basic concepts using practical examples.

## Creating Your First Resource

The easiest way to get started is with ``QuickFork``, which manages a single value in memory:

```swift
import Forked

// Create a QuickFork holding an integer
let counter = QuickFork<Int>(initialValue: 0)

// Read the initial value from the main fork
let value = try counter.value(in: .main)! // Returns 0
```

> Note: `value(in:)` returns an optional because the value might not exist in a given fork. When you're sure the value exists (like right after creation), you can force unwrap with `!`. In production code, you might want to handle the optional more safely.

## Working with Forks

### Creating Named Forks

While every resource has a `.main` fork, you'll often want to create additional named forks. One convenient approach is to define your forks as static properties in an extension to `Fork`:

```swift
extension Fork {
    static let ui = Fork(name: "ui")
    static let background = Fork(name: "background")
    static let network = Fork(name: "network")
}

// Create a resource with multiple forks
let counter = QuickFork<Int>(
    initialValue: 0,
    forks: [.ui, .background, .network]
)

// Using static properties makes the code more readable
try counter.update(.ui, with: 1)
try counter.mergeIntoMain(from: .ui)
```

You can also create forks directly if you prefer:

```swift
let customFork = Fork(name: "custom")
```

### Updating Values

You can update values independently in different forks:

```swift
// Update values directly
try counter.update(.ui, with: 1)
try counter.update(.main, with: 2)

// Each fork maintains its own value
let uiValue = try counter.value(in: .ui)!      // Returns 1
let mainValue = try counter.value(in: .main)!     // Returns 2
```

### Merging Changes

When you're ready to reconcile changes between forks, you can merge them. All merges must go through the `main` fork - you cannot merge directly between custom forks:

```swift
// Merge the UI fork into main
try counter.mergeIntoMain(from: .ui)

// To get changes from UI fork to background fork:
// 1. First merge UI into main (as above)
// 2. Then merge from main into background
try counter.mergeFromMain(into: .background)
```

### Merging Direction

Merging is directional - changes flow from the source fork to the destination fork. To fully synchronize two forks, you need to merge in both directions:

```swift
// Merge changes from UI to main
try counter.mergeIntoMain(from: .ui)

// Merge changes from main to UI
try counter.mergeFromMain(into: .ui)
```

For convenience, there's a `syncMain(with:)` method that performs bidirectional merges between main and multiple forks:

```swift
// Synchronize main with UI and background forks
try counter.syncMain(with: [.ui, .background])
```

Remember that syncing between custom forks still requires going through `main`. The sync method makes this easier by handling all the necessary merges in each direction.

## Working with Complex Types

While the examples above use simple `Int` values, Forked really shines when working with complex types. Here's an example using a custom type:

```swift
struct Counter: Mergeable {
    var count: Int = 0
    
    // Define how instances should be merged
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        // Add the changes from both forks
        let selfDelta = self.count - commonAncestor.count
        let otherDelta = other.count - commonAncestor.count
        return Counter(count: commonAncestor.count + selfDelta + otherDelta)
    }
}

// Create a resource with our custom type
let counter = QuickFork<Counter>(
    initialValue: Counter(),
    forks: [.ui, .background]
)

// Update values in different forks
var uiCounter = try counter.value(in: .ui)!
uiCounter.count += 1
try counter.update(.ui, with: uiCounter)

var mainCounter = try counter.value(in: .main)!
mainCounter.count += 2
try counter.update(.main, with: mainCounter)

// Merge the changes
try counter.mergeIntoMain(from: .ui)

// Both increments are preserved
let result = try counter.value(in: .main)!.count // Returns 3
```

## Next Steps

- Learn about different merging strategies in <doc:MergingStrategy>
- Explore automatic model generation with ``ForkedModel``
- Add CloudKit sync with ``ForkedCloudKit`` 