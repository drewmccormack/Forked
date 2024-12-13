# ``Forked``

A framework for handling shared data with confidence in Swift.

## Overview

Forked provides a comprehensive solution for managing concurrent data access and synchronization through a Git-inspired branching and merging system. Instead of using traditional concurrency primitives like locks or actors, Forked allows you to safely work with multiple copies of data and merge them systematically.

## Key Concepts

### Forks
A fork represents a branch of your data that can be modified independently of other branches. Every ``ForkedResource`` has a `main` fork, and you can create additional named forks for different purposes like UI updates, background processing, or network synchronization.

### Resources
A ``ForkedResource`` manages the state and history of your data across multiple forks. It tracks changes, maintains the common ancestor states needed for merging, and provides methods for updating and querying values in different forks.

### Merging
When forks diverge and need to be reconciled, Forked provides sophisticated merging capabilities. The framework supports both automatic merging for simple types and custom merge strategies for complex data structures.

### Repositories
A ``ForkedResource`` does not actually store any data: it just contains the logic for managing forks and resources. Repositories provide the storage for a `ForkedResource`, whether it be in memory, on disk, in a database, or in the cloud.

## Topics

### Essentials

- <doc:GettingStarted>
- ``ForkedResource``
- ``Mergeable``
- ``Repository``

### Working with Resources

- ``QuickFork``
- ``ForkedResource/create()``
- ``ForkedResource/update(_:with:)``
- ``ForkedResource/value(in:)``
- ``ForkedResource/mergeIntoMain(from:)``
- ``ForkedResource/mergeFromMain(into:)``

### Merging and Conflict Resolution

- ``Mergeable``
- ``ForkedMerge``
- ``ForkedModel``

### Packages

- ``ForkedMerge``
  A collection of built-in merge algorithms
- ``ForkedModel``
  Macro-based tools for generating mergeable data models
- ``ForkedCloudKit``
  CloudKit integration for multi-device synchronization

### Articles

- <doc:GettingStarted>
- <doc:CloudKitIntegration>
- <doc:ForkedInnards>

