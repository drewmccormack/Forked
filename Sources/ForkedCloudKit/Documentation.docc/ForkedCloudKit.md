# ``ForkedCloudKit``

CloudKit integration for forked data structures.

## Overview

ForkedCloudKit provides seamless integration with Apple's CloudKit framework for syncing forked data.

## Enabling the CloudKit Trait

For full functionality — including debouncing of change notifications — enable the `CloudKit` trait on the Forked package dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/drewmccormack/Forked.git", from: "0.1.0", traits: ["CloudKit"])
```

Without the trait, `ForkedCloudKit` still works, but change monitoring will not debounce rapid updates before uploading.