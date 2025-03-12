![Forked: Share Data with Confidence](https://raw.githubusercontent.com/drewmccormack/Forked/main/Sources/Forked/Documentation.docc/Resources/ForkedGardenBanner.png)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FForked%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/drewmccormack/Forked)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FForked%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/drewmccormack/Forked)

Forked provides a generalized approach to managing shared data in Swift applications, both on-device — avoiding race conditions — and across devices as a framework for offline-first and [local-first](https://www.inkandswitch.com/local-first/) software.

Forked can operate within a single iOS app, on a Swift server, or distributed across a network. The `ForkedCloudKit` package, for example, supports syncing of data across devices in just a few lines of code.

In short, what's forking stopping you?![^goodplace]

## Quick Start

### Try Before You Buy

Nobody wants to invest time in a framework without knowing if it's right for them, so we have uploaded the [Forkers](https://apps.apple.com/us/app/forkers/id6739265992) sample app to the App Store for you to try. (Note that it is unlisted, so use the link instead of searching.) The Forkers app is built on Forked, and the source code is right here. Try it out, and don't forget to test out the iCloud sync!

### Installation

#### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/drewmccormack/Forked.git", from: "0.1.0")
]
```

#### Xcode

1. Select your project in the navigator
2. Open the Package Dependencies tab
3. Click + and enter: `https://github.com/drewmccormack/Forked.git`
4. Add `Forked` and any of the subpackages you need

## Key Features

- **Safe**: Prevents data races and manages race conditions without locks, queues, or actors
- **Swift Values**: Model data with `Sendable` value types that pass easily between threads and isolation domains
- **Simple Setup**: 100% Swift, no complex configuration needed
- **Smart Sync**: Git-inspired branching and merging lets you track changes on a single device or across many
- **Supports Local-First**: [Local-first](https://www.inkandswitch.com/local-first/) apps are all the rage, and Forked makes it easy to get started
- **Smashable**: Advanced 3-way merging algorithms (_eg_ CRDTs) intelligently handle conflicts
- **Saveable**: Full `Codable` support for easy persistence to disk and cloud services
- **Seamless iCloud**: Built-in CloudKit integration for effortless multi-device synchronization
- **Scalable**: You can start using Forked with your own data types, and scale up to complete data models when it suits
- **Self Service**: You can add custom storage for Forked data, and integrate with custom cloud services
- **Succinct**: Unlike Git, Forked only keeps the bare essentials for merging, not a complete history of all changes

## How it Works

Forked is based on a decentral model similar to Git. It tracks changes to a shared data resource, and resolves conflicts using 3-way merging. You are in control, and never lose any changes to your data.

In contrast to locks, queues, and actors, Forked doesn't serialize access to a resource. Instead, Forked provides a branching mechanism to systematically create copies of the data, which can be modified concurrently, and merged at a later time.

Forked takes care of all the logic involved in the branching process, including keeping a copy of the data at the point that branches (known as _forks_) diverge. This 'divergence' copy is known as the _common ancestor_, and it is important, because when it comes time to merge the forks again, Forked can use it to determine what was changed, and in which fork(s).

You can merge branches safely at any time with Forked — in any order — using powerful merging algorithms that go way beyond what is available in other data modeling frameworks. For example, Forked utilizes so-called Conflict-Free Replicated Data Types (CRDTs) to merge text in a way that would seem logical to people, rather than choosing a solution with results only a machine could love.

## Show Me The Forking Code!

Ready to play? Let's learn about Forked by example.

### A Simple Forking Example

Here is your first fork:

```swift
import Forked
let uiFork = Fork(name: "ui")
let intResource = QuickFork<Int>(initialValue: 0, forks: [uiFork])
```

`QuickFork` is a convenient way to create an in-memory `ForkedResource` holding a single value, in this case an `Int`.

We have also declared `uiFork`, which is a named fork. Aside from forks you create yourself, all `ForkedResource` instances have a central fork called `main`, which can be merged with any other fork.

Let's update the `Int` on `uiFork`, and independently on the `main` fork, then merge to get the result:

```swift
try intResource.update(uiFork, with: 1)
try intResource.update(.main, with: 2)
try intResource.mergeIntoMain(from: uiFork)
let resultInt = try intResource.value(in: .main)!
```

The `resultInt` will be `2` in this case, because that was the value set most recently. 

### Controlled Forking

For an atomic type like an `Int`, the results of merging are not very interesting; the real power of Forked comes from its ability to merge complex data types. 

Let's start by defining a struct so we can control the merging behavior of the `Int`.

```swift
struct AccumulatingInt: Mergeable {
    var value: Int = 0
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        return AccumulatingInt(value: self.value + other.value - commonAncestor.value)
    }
}
```

By conforming to the `Mergeable` protocol, `AccumulatingInt` has total control over how it is merged.

The `Mergeable` protocol requires the func `merged(withSubordinate:commonAncestor:)`. The `subordinate` is a conflicting value from another fork, and `commonAncestor` is the value at the point that the two forks diverged.

The merge algorithm of `AccumulatingInt` determines what has changed on each fork since the common ancestor was created, and tallies these changes up to produce a new value.

If we were to use an `AccumulatingInt` in the original example, instead of an `Int`, the result would be `3`, because the `uiFork` incremented by `1`, and the `main` fork incremented by `2`, giving a total of `3`.

### Merging Algorithms

So you can come up with structs that can merge in any way that you choose, but those merging algorithms can quickly get complex. That's where the subpackage `ForkedMerge` comes in: it provides standard built-in merging algorithms.

Imagine we are developing a text editor with this oversimplified model:

```swift
import Forked
import ForkedMerge

struct TextDocument: Mergeable {
    var text: String = ""
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        let newText = try TextMerger().merge(
            self.text, 
            withSubordinate: other.text, 
            commonAncestor: commonAncestor.text
        )
        return TextDocument(text: newText)
    }
}
```

It doesn't look like much, but you've just created the model for a fully collaborative text editor. For example, if the model initially contains the text "Fork Yeah", and...

1. One user changes this to "Fork Yeah!!!"
2. Another changes it at the same time to "Fork yeah"
3. `TextMerger` will merge to give "Fork yeah!!!"

### Modeling Data

Having complete control over merging is great, and the merging algorithms provided by `ForkedMerge` make it much easier to piece things together, but wouldn't it be nice if `Forked` could just generate this code automatically? 

That's exactly what `ForkedModel` is for. It uses Swift Macros to make defining a global data model almost trivial. 

Let's update `TextDocument` to use `ForkedModel`:

```swift
import Forked
import ForkedModel

@ForkedModel
struct TextDocument {
    @Merged var text: String = ""
}
```

"Where's the rest?" I hear you cry. There is no rest! That's the forking lot!

This code is equivalent to the code we wrote manually in the previous section. It could form the basis of a fully collaborative text editor, or simply a personal editor syncing via iCloud.

And it doesn't stop there: each property in the struct gets merged independently. You can choose from a standard _atomic_ merge for simple types, to advanced merging algorithms for common Swift types like `String`, `Array`, `Dictionary`, and `Set`.

To demonstrate, here is a more complex example of `TextDocument`:

```swift
import Forked
import ForkedModel

@ForkedModel
struct TextDocument {
    var id: UUID = UUID()
    @Merged var text: String = ""
    @Merged var tags: Set<String> = []
    @Merged(using: .textMerge) var comment: String = ""
    @Merged var editCount: AccumulatingInt = .init()
    var cursorPosition: Int = 0
}
```

The `@Merged` attribute tells `ForkedModel` that the property is `Mergeable`, and it should use an appropriate merging algorithm. There are defaults for most common types, but you can override this by passing a different merge algorithm to the `using:` parameter. 

If you have a custom `Mergeable` type, like `AccumulatingInt`, applying `@Merged` will cause it to merge using the `merged(withSubordinate:commonAncestor:)` method you provided. 

Properties without `@Merged` attached will be merged atomically, with a more recent change taking precedence over an older one. Properties will be merged in a property-wise manner, based on the most recent change to the property itself

## Sample Code

A good way to get started with `Forked` is to take a look at the sample apps provided. They range in difficulty from very basic, to a fully-functional iCloud-based Contacts app. 

##### [A Race of Actors](https://github.com/drewmccormack/Forked/tree/main/Samples/A%20Race%20of%20Actors)
Actors solve the problem of data races in Swift very well, but they don't help at all with race conditions, and can even give rise to new ones. This sample shows you can use a `ForkedResource` inside of an actor to deal with race conditions in a straightforward way.

##### [Forked Model](https://github.com/drewmccormack/Forked/tree/main/Samples/Forked%20Model)
Sets up a simple mergeable model similar to the ones above. The UI allows you to change the values of text and a counter in two different forks, and pressing a button you see how they get merged.

##### [Forking Simple iCloud](https://github.com/drewmccormack/Forked/tree/main/Samples/Forking%20Simple%20iCloud)
The model in this sample is extremely simple, and is secondary in importance to how you setup the `CloudKitExchange` to sync data with iCloud. The sample shows how you can use a `ForkedResource` for storage on disk, update a property for display in SwiftUI, and monitor changes to forks in order to refresh the UI when changes arrive from iCloud.

##### [Forkers](https://github.com/drewmccormack/Forked/tree/main/Samples/Forkers)
Forkers is a contacts app for keeping track of your favorite forkers. The model is more complex than the other samples, showing how you can nest `Mergeable` types, in this case with an `Array` of your contacts. It also integrates with iCloud, giving a fully-functional, local-first contacts app.

## Docs

Documentation is available for each subpackage.

##### [Forked](https://drewmccormack.github.io/Forked/Forked/documentation/forked)
This is the core package, and needed to use any of the other packages. It provides `ForkedResource`, which is the basic building block of `Forked`.

##### [ForkedMerge](https://drewmccormack.github.io/Forked/ForkedMerge/documentation/forkedmerge)
This package provides the standard merging algorithms for `Mergeable` types. It also includes a number of Conflict-Free Replicated Data Types (CRDTs).

##### [ForkedModel](https://drewmccormack.github.io/Forked/ForkedModel/documentation/forkedmodel)
This package provides the `@ForkedModel` and `@Merged` macros, which allow you to define a global data model using value types.

##### [ForkedCloudKit](https://drewmccormack.github.io/Forked/ForkedCloudKit/documentation/forkedcloudkit)
This provides the `CloudKitExchange` class, which automatically syncs a `ForkedResource` between devices with iCloud.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

Forked is available under the MIT license. See the LICENCE file for more info.

[^goodplace]: "Forking" jokes are inspired by [The Good Place](https://en.wikipedia.org/wiki/The_Good_Place). Go watch it!
