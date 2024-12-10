
# Sample: Forkers

This sample presents a complete app for storing contact details of your favorite forkers. 
It shows how to build a data-driven SwiftUI app centered around a `ForkedResource`.

Data is stored in a `ForkedResource`, which saves to disk using `Codable`. Forkers syncs between 
devices via iCloud using `ForkedCloudKit`. 

The `Store` class is the central point of the app, and is responsible for managing the `ForkedResource`, 
and populating the UI with the data.

The main model class is `Forker`. It is a struct with a variety of properties, including enums, strings, 
and the custom `Mergeable` type `Balance`.

The `Forkers` type is effectively the array of `Forker` objects from the app. It is setup to 
use a special type of array merging, which enforces uniqueness of identifiers, and also recursively
merges the elements of the array when merging.

