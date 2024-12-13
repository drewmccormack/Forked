# Forked Innards: Understanding the Architecture

Forked is built around a simple yet powerful concept: data conflicts should be treated as a natural part of software systems rather than an exceptional state.

## Centralized vs Decentralized

### The Traditional Approach

Applications traditionally use a centralized approach to manage shared data. At the heart of this approach lies a central coordinator, such as a lock, queue, or actor, which protects the shared resource, providing serial access to it. 

While this pattern is familiar, it comes with significant drawbacks. Changes must be synchronized through the coordinator, forcing other parts of the system to wait while changes occur. This not only creates bottlenecks and synchronization costs but also makes it challenging to reason about the system's state, often leading to subtle race conditions.

### The Decentralized Way

Forked takes inspiration from proven distributed version control systems like Git. With these systems, changes flow more naturally. Developers can work independently, without waiting to coordinate with other developers. When conflicts arise, the system has a complete picture of what's changed through its history tracking.

This philosophy translates directly to how Forked operates in your application. You're free to modify data without considering other subsystems or devices, and reconciliation happens later through well-defined merge policies. The key innovation is Forked's support for 3-way merging, where a historical "common ancestor" helps determine exactly what's changed in each fork when a conflict arises.

### The Reality of Modern Apps

Most modern applications are inherently decentralized, whether intentional or not. Consider how your app might sync data across multiple devices, or how app extensions operate in separate processes on shared data. Even background processes performing imports or downloads from a web service must coordinate with the main app. These scenarios all represent decentralized operations, even if we often try to force them into a centralized model.

### Sync Comes for Free

Forked's decentralized approach means that sync is a natural part of the system. By providing some limited history tracking, in the form of a common ancestor, as well a powerful merging, you can begin developing an app for a single device, and very simply add support for sync with no model changes, and no custom server. Just connect iCloud, and you're done.

## Forked and Actor-Based Systems

While actors excel at preventing data races through controlled access to shared resources, they can't prevent higher-level race conditions or solve the complexities of reentrant code and interleaved operations. This is where Forked steps up, complementing actor-based architectures by providing robust conflict management capabilities.

## Architectural Components

### The Forked Hub

Rather than implementing a full version control system, Forked maintains just enough history for effective 3-way merging, keeping memory usage low. In optimal cases, the size of a `ForkedResource` is practically the same as the size of the resource it contains.

In a `ForkedResource`, forks are arranged in a hub-and-spoke pattern. The hub is the main fork, while other forks (the spokes) can merge with the main fork, but not directly with each other.

![The hub-and-spoke architecture of Forked.](ForkedHub "A diagram showing the hub-and-spoke architecture of Forked. The main fork is in the center, with other forks radiating outward like spokes on a wheel. The smaller black dots represent copies of the resource.")

The main fork in the hub stores exactly one copy of the resource — its current value. Other forks, on the other hand, are responsible for keeping track of the common ancestor when updates occur. In this way, a 3-way merge between the main fork and any other fork can be performed at any time.

The non-main forks can contain various copies of the resource, based on their relationship to the main fork:

- When a fork is in sync with the main fork, it stores no additional copies of the resource
- When the main fork has progressed ahead, the fork retains only the common ancestor copy
- When the fork conflicts with the main fork, it maintains two copies: the common ancestor and its own most recent value

Whenever an update to any fork is made, copies of the resource into forks can arise. For example, take the simple case that all forks are in sync. If an update occurs to the main fork, a copy of the resource is made into all of the non-main forks, because they all need a common ancestor to perform a 3-way merge in future. Later, if the main fork gets fully synced with one of the other forks, that fork will no longer have any copy of the resource.

This careful management of state means that:
- The minimum necessary history is preserved in order to facilitate 3-way merges
- When all forks are in sync, only one copy of the resource exists in memory
- Memory usage scales with the number of conflicts, not with the number of forks
- The spoked architecture keeps the number of common ancestors low, because they aren't needed for every single pair of forks

