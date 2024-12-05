
# Sample: Forking Simple iCloud

This is about the simplest app you could make with the `ForkedCloudKit` package. It's a simple text editor that syncs with iCloud.

This app simple stores a standard `Codable` struct (`Model`) in a record in CloudKit. 

The `ForkedCloudKit` package takes on a bunch on task so you don't have to...

1. It creates two branches in the `ForkedResource` which is uses to keep track of the state.
2. It monitors changes in CloudKit, and will import new data into the `ForkedResource`.
3. It will automatically upload new changes made to the `.main` fork.
4. It automatically merges the CloudKit forks into and from `.main`.

There are some other aspects of this sample that are interesting:

1. You can see how to monitor changes to forks using a `changeStream`.
2. You can see how to save a `ForkedResource` to disk.
3. You can see how to query forks and create new ones.

If you want to use CloudKit with Forked, don't forget to setup the entitlements of your app. You need...

1. iCloud entitlements, with a CloudKit container.
2. Turn on background modes for background fetch and remote notifications.
3. Configure the `CloudKitExchange` to use the `CKContainer` you have setup, and the record name (`id`).

