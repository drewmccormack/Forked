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
    forkedResource: forkedResource,
    unknownModelVersionHandler: { error in
        // Handle unknown model version by printing the error
        // In a real app, you might want to show a UI alert telling the user to update
        print("Error: \(error)")
    }
)
```

The `id` parameter should be a unique string that identifies this resource in CloudKit.

## How It Works

CloudKitExchange automatically:

1. Monitors changes to your ForkedResource's main fork
2. Uploads changes to iCloud when detected
3. Downloads changes from other devices
4. Before merging any changes, it checks the model version of the remote data and the local data. If the model version from iCloud is one that is unknown in the local app, it calls the `unknownModelVersionHandler` closure, and stops syncing. The user should update their app to the latest version.
5. If the model is known, it merges the remote changes into your local data on the main fork

All of this happens in the background without blocking your app's UI.

## Model Versioning

ForkedCloudKit requires your model to conform to `VersionedModel` to ensure safe syncing across different app versions. This is crucial because:

1. Different versions of your app may have different data models
2. When syncing, you need to ensure the app can understand the data it receives
3. Older versions of your app should not try to merge data from newer, unknown model versions

Here's how to make your model versioned:

```swift
@ForkedModel(version: 1)
struct MyData {
    ...
}
```

When you update your model in a new app version, increment the version by 1.

If CloudKitExchange encounters data with an unknown version (higher than the version in the code):

1. It calls your `unknownModelVersionHandler` closure
2. Stops syncing to prevent data corruption
3. The user should be prompted to update their app

## Example Implementation

Here's a complete example showing how to integrate CloudKit sync into a SwiftUI app:

```swift
@Observable
@MainActor
class Store {
    private let repo: AtomicRepository<MyData>
    private let forkedResource: ForkedResource<AtomicRepository<MyData>>
    private var cloudKitExchange: CloudKitExchange<AtomicRepository<MyData>>!

    /// Set to true when the user needs to upgrade their model
    public var showUpgradeAlert = false
    
    init() throws {
        // Setup local storage
        let fileURL = // ... your file URL
        repo = try AtomicRepository(managedFileURL: fileURL)
        forkedResource = try ForkedResource(repository: repo)
        
        // Initialize CloudKit sync
        cloudKitExchange = try CloudKitExchange(
            id: "<Unique ID for the repo in CloudKit>",
            forkedResource: forkedResource,
            unknownModelVersionHandler: { [weak self]error in
                self?.showUpgradeAlert = true
            }
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
    cloudKitContainer: container,
    unknownModelVersionHandler: { error in
        print("Error: \(error)")
    }
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
- **Data Not Appearing**: Check that your CloudKit container is properly configured. 
- **No Sync in Production Version**: Make sure you push your CloudKit schema to production before launching your app. Use the CloudKit web portal (https://icloud.developer.apple.com) to do this
- **Conflicts**: ForkedCloudKit automatically handles conflicts using your resource's merge strategy

## Further Reading

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Forked Documentation](https://github.com/drewmccormack/Forked)
- Sample App: [Forking Simple iCloud](https://github.com/drewmccormack/Forked/tree/main/Samples/Forking%20Simple%20iCloud) 