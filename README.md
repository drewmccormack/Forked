# Forked

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FForked%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/drewmccormack/Forked)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FForked%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/drewmccormack/Forked)

Forked provides a forking data structure to manage concurrent access to shared resources in Swift.
You can protect shared data, preventing corruption and guaranteeing validity, without locks, queues,
or even actors. 

In short, it's forking brilliant! [1] 

[1] "Forking" jokes are inspired by [The Good Place](https://en.wikipedia.org/wiki/The_Good_Place).

## Features

Scroll down for a fuller discussion of Forked. Here is the tldr; summary.

- Existing approaches to sharing data can easily lead to invalid state
    - Actors suffer from data races due to interleaving
    - Locks can deadlock, and require disipline to use right
    - Queues can also deadlock, and tend to result in verbose code
- Forked...
    - Provides a shared data structure that avoids these issues
    - Restricts access to shared data, like an actor
    - Can be used where different subsystems are updating the same data
    - Works with other shared resources, like files
    - Can be used to manage sharing with remote servers
    - Can be used to sync your data via CloudKit and other services
- How it works
    - Forked is based on a decentral model similar to Git
    - It tracks changes to a shared resource, and resolves conflicts using 3-way merging
    - You are in control, and never lose changes to your data. Fork yeah!

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Installation

### Swift Package Manager

To add Forked to your project, add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/drewmccormack/Forked.git", from: "0.1.0")
]
```

And then add the Forked library to your target.

### Importing

In the files where you want to use Forked, import it:

```swift
import Forked
```

## Usage

Define your shared data type

Define how you want it to merge if a conflict should arise due to concurrent changes

Decide what subsystems need to access it, and make forks for each

Only one subsystem should update a given fork

One rule of fork club: keep a fork chronological. 
Only update a fork with new data that comes after what is already in the for

We plan to add tools to help with merging of data. So before you get discouraged,
it's forking comin', OK?!

## Beyond Locks, Queues and Actors

As a Swift developer, you have a variety of tools available to you in order
to control access to shared data. 

Actors are the most recent means of protecting shared data in Swift, and they do 
guarantee that your data will not be corrupted by concurrent access from 
multiple threads. 

Unfortunately, actors can
experience _interleaving_, whereby a race may arise when you include any 
async funcs. This makes it difficult to make guarantees about data validity. 
Funcs can be in-flight at the same time, modifying shared data in unexpected ways.
Your data may end in an unexpected state, and can even be completely invalid. 
What the fork?!

Queues (eg `Dispatch`) and locks (eg `NSLock`) have been around longer, and can also prevent
concurrent access to shared data. What's more, they don't suffer from the same
interleaving issues that actors do. However, improper use can lead to deadlocks (freezes), or 
temporary blockages of threads, which may result in undesirable
glitches in an app's user interface.

Forked provides a data structure which can be used across threads, and 
guarantees not only that shared data is uncorrupted, but also is in a valid state.
Data races, interleaving and deadlocks are not possible with Forked.

## Forked and Actors

May seem forked replaces them

Not true. Forked just takes over one aspect of actors, namely, controlling access to shared data

Forked does not provide any executable code, it is purely a data structure

An actor has executable code

You can use the two together

Take this scenario

```
struct AppData { ... }

actor Store {
    private var appData: AppData

    func download() async {
        // Code including suspension points (await)
        ...
    }
    
    func import() async {
        // Code including suspension points (await)
        ...
    }
    
    func userEntry() {
        ...
    }    
}

```
This actor is charged with storing your app's data, and can be updated in a
variety of different ways. The user could make changes; a long running data 
import may take place, and data may even be downloaded from a server. The 
funcs `import` and `download` are asynchronous, and can await other funcs.

With this design, there is a reasonable chance that if any of the funcs are
in-flight at the same time, or even invoked repeatedly, `sharedData` will
end up invalid, or simply not contain all the changes. The actor will prevent
concurrent access from different threads, but will not guarantee that only one
func is in-flight at the same time, meaning it will be very easy for, say, a
`download` to overwrite changes made by the user.

Here is the same setup using Forked, which guarantees no data will ever be lost.

```
struct AppData: Resource { ... }
struct AppDataResolver: Resolver { ... }

actor Store {
    private let forkedAppData: ForkedResource<AppData>
    
    private let resolver = AppDataResolver()
    private let downloadFork = Fork(name: "download")
    private let importFork = Fork(name: "import")
    private let userEntryFork = Fork(name: "userEntry")

    init() {
        // Create new forked resource (if needed)
        forkedAppData = ForkedResource<AppData>()
        forkedAppData.update(.main, with: AppData())
        forkedAppData.create(downloadFork)
        forkedAppData.create(importFork)
        forkedAppData.create(userEntryFork)
    }

    func download() async {
        // Get latest data
        forkedAppData.mergeAllForks(into: .downloadFork, resolver: resolver)
        var appData: AppData = forkedAppData.resource(of: downloadFork)!
        
        // Update appData with downloaded data (async)
        ...
        
        // Save
        forkedAppData.update(downloadFork, with: appData)
    }
    
    func import() async {
        // Get latest data
        forkedAppData.mergeAllForks(into: importFork)
        var appData: AppData = forkedAppData.resource(of: importFork)!
        
        // Update appData with imported data (async)
        ...
        
        // Save
        forkedAppData.update(importFork, with: appData)
    }
    
    func userEntry() {
        ...
    }    
}

```

## Beyond Actors

If you thought that Swift actors could protect shared data, you are only half right. 
It is true that an actor will prevent concurrent access to a shared resource from
multiple threads, thereby ensuring it is not corrupted. But actors do not prevent
data races, and can lead to unexpected behavior, and difficult to track down bugs.
In short, your shared data may not be corrupted, but it may not be valid either.

Take this simple example of an actor that maintains a count.

```swift
actor Counter {
    var sum: Int = 0
    
    func addOne() {
        sum += 1
    }
    
    func addTwo() {
        sum += 2
    }
}

Task {
    let counter = Counter()
    async let first = await counter.addOne()
    async let second = await counter.addTwo()
    _ = await [first, second]
    let result = await counter.sum
    print("The result is \(result)")
}
```

So far, so good. Even though we have deliberately called the `addOne` and `addTwo`
funcs concurrently, we can be sure that each func is executed serially, 
and the result is always 3.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

Forked is available under the MIT license. See the LICENSE file for more info.


