
# Sample: A Race of Actors

Q: What do you call a group of many Swift actors?
A: A race of actors.

Joking aside, this sample is a rather contrived example of how you can quite easily
get race conditions in your async code, even when an actor guarantees to protect it against data races.

In this example, we setup two actor types, one that includes a simple integer property, and an
async `addOne` method, and another which uses a `ForkedResource` to control updates to the integer instead.

We then call each actor concurrently from 100 tasks. The expectation is that we will get the result 100,
since each call increments the integer by one. However, the standard actor (`LousyContestant`)
experiences race conditions, and is unlikely to get the right answer.

The `ForkedContestant` actor, on the other hand, uses a `ForkedResource` to manage the integer, and
protects it by creating a fork to handle changes during each call. This isolates the updates from
concurrent calls — only the call that created the fork can update it. Merging of each fork into `.main`
ensures that the correct result is returned at the end.

Obviously this is a trivially simple case, and removing the pause in `addOne` would fix the issue, but
in more advanced cases, it is quite easy to miss a race like this. Isolating code that writes to
a property, using a fork, is a safe way to prevent a race condition, and thereby get the right answer.
