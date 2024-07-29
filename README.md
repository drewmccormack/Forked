# ForkedResource

[![Swift Version](https://img.shields.io/badge/swift-5.7-orange.svg)](https://swift.org/download/)
[![Platform](https://img.shields.io/badge/platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux-lightgrey.svg)](https://swift.org/platform-support/)

ForkedResource provides a forking data structure to manage concurrent updates to shared resources in a Swift app. 

## Features

- Forking data structure to manage concurrent updates
- No blocking read/write of shared data and files

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Installation

### Swift Package Manager

To add ForkedResource to your project, add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/drewmccormack/ForkedResource.git", from: "0.1.0")
]
```

And then add the ForkedResource library to your target.

### Importing

In the files where you want to use ForkedResource, import it:

```swift
import ForkedResource
```

## Usage


## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

ForkedResource is available under the MIT license. See the LICENSE file for more info.
