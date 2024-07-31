# Forked

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FForked%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/drewmccormack/Forked)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FForked%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/drewmccormack/Forked)

Forked provides a forking data structure to manage concurrent updates to shared resources in a Swift app. 

## Beyond Locks, Queues and Actors

As a Swift developer, you have a variety of tools available to you in order
to control access to shared data. 

Actors are the most recent means of protecting shared data in Swift, and they do 
guarantee that your data will not be corrupted by concurrent access from 
multiple threads. 

Unfortunately, actors can
experience _interleaving_, whereby a race may arise between multiple invocations of 
async funcs. This makes it difficult to make guarantees about data validity. 
Even though your data is protected from corruption, it may end in an unexpected state, 
and can even be completely invalid.

Queues (eg `Dispatch`) and locks (eg `NSLock`) have been around longer, and can also prevent
concurrent access to shared data. What's more, they don't suffer from the same
interleaving issues that actors do. However, improper use can lead to deadlocks (freezes), or 
temporary blockages of threads, which may result in undesirable
glitches in an app's user interface.

Forked provides a data structure which can be used across threads, and 
guarantees not only that shared data is uncorrupted, but also is in a valid state.
Data races, interleaving and deadlocks are not possible with Forked.

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

## Features

- Forking data structure to manage concurrent updates
- No blocking read/write of shared data and files

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

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

Forked is available under the MIT license. See the LICENSE file for more info.
