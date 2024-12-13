
# Sample: Forkers

This sample presents a complete app for storing contact details of your favorite forkers. 
It shows how to build a data-driven SwiftUI app centered around a `ForkedResource`.

Data is stored in a `ForkedResource`, which saves to disk using `Codable`. Forkers syncs between 
devices via iCloud using `ForkedCloudKit`. 

The `Store` class is the central point of the app, and is responsible for managing the `ForkedResource`, 
and populating the UI with the data.

The main model class is `Forker`. It is a struct with a variety of properties, including enums, strings, 
and the custom `Mergeable` type called `Balance`.

The `Forkers` type is effectively just an array of `Forker` objects. It is setup to 
use a special type of array merging, which enforces uniqueness of identifiers, and also recursively
merges the elements of the array when merging.

> The Forkers sample app is available in the [App Store](https://apps.apple.com/us/app/forkers/id6739265992) for you to try before installing Forked. Note that the app is unlisted, so you can't search for it. Use the link provided instead.
