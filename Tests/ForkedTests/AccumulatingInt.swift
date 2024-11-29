import Forked

struct AccumulatingInt: Mergeable, Equatable {
    var value: Int = 0
    func merged(withOlderConflicting other: AccumulatingInt, commonAncestor: AccumulatingInt?) throws -> AccumulatingInt {
        AccumulatingInt(value: value + other.value - (commonAncestor?.value ?? 0))
    }
}
