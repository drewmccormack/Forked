# CloudKit Integration Guide

Learn how to use ForkedCloudKit to sync your data across devices.

## Overview

ForkedCloudKit makes it easy to sync your Forked data between devices using Apple's CloudKit framework. This guide will walk you through the basic setup and usage.

## Getting Started

First, make sure you have the ForkedCloudKit subpackage added to your project dependencies.

Then import ForkedCloudKit in your source files:

```swift
import Forked
import ForkedCloudKit
```

## Basic Setup

The main class you'll work with is `CloudKitExchange`. Here's how to set it up:

```swift
// Create a ForkedResource for your data
let repo = try AtomicRepository(managedFileURL: fileURL)
let forkedResource = try ForkedResource(repository: repo)

// Create CloudKitExchange instance
let cloudKitExchange = try CloudKitExchange(
    id: "<Unique ID for the repo in CloudKit>",
    forkedResource: forkedResource
)
```

The `id` parameter should be a unique string that identifies this resource in CloudKit.

## How It Works

CloudKitExchange automatically:

1. Monitors changes to your ForkedResource's main fork
2. Uploads changes to iCloud when detected
3. Downloads changes from other devices
4. Merges remote changes into your local data on the main fork

All of this happens in the background without blocking your app's UI.

## Example Implementation

Here's a complete example showing how to integrate CloudKit sync into a SwiftUI app:

```swift
@MainActor
class Store {
    private let repo: AtomicRepository<MyData>
    private let forkedResource: ForkedResource<AtomicRepository<MyData>>
    private let cloudKitExchange: CloudKitExchange<AtomicRepository<MyData>>
    
    init() throws {
        // Setup local storage
        let fileURL = // ... your file URL
        repo = try AtomicRepository(managedFileURL: fileURL)
        forkedResource = try ForkedResource(repository: repo)
        
        // Initialize CloudKit sync
        cloudKitExchange = try CloudKitExchange(
            id: "<Unique ID for the repo in CloudKit>",
            forkedResource: forkedResource
        )
    }
}
```

## CloudKit Setup in Xcode

Before your app can use CloudKit:

1. Enable iCloud in your Xcode target's capabilities tab
2. Choose or add a container (_eg_ "iCloud.com.mycompany.myapp"). The container ID should match the `id` parameter in your `CloudKitExchange` initializer.
2. Also enable the background modes for remote notifications and background processing

## Advanced Usage

### Custom Container

By default, CloudKitExchange uses the default CloudKit container. You can specify a custom container:

```swift
let container = CKContainer(identifier: "iCloud.com.mycompany.myapp-another-container")
let cloudKitExchange = try CloudKitExchange(
    id: "<Unique ID for the repo in CloudKit>",
    forkedResource: forkedResource,
    cloudKitContainer: container
)
```

### Monitoring Sync Updates

CloudKitExchange automatically handles sync in the background, but you can monitor when changes from CloudKit are merged into your main fork.

To do this, add a `Task` on launch that monitors the `changeStream` for changes from CloudKit:

```swift
Task {
    for await change in forkedResource.changeStream 
        where change.fork == .main && change.mergingFork == .cloudKit {
        // Handle changes merged from CloudKit into main fork
    }
}
```

## Troubleshooting

Common issues and solutions:

- **No Sync**: Ensure iCloud is enabled on the device, the user is signed in, and iCloud Drive enabled
- **Data Not Appearing**: Check that your CloudKit container is properly configured
- **Conflicts**: ForkedCloudKit automatically handles conflicts using your resource's merge strategy

## Further Reading

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Forked Documentation](https://github.com/drewmccormack/Forked)
- Sample App: [Forking Simple iCloud](https://github.com/drewmccormack/Forked/tree/main/Samples/Forking%20Simple%20iCloud) 