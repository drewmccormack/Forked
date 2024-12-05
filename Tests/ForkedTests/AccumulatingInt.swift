import Forked

struct AccumulatingInt: Mergeable, Equatable {
    var value: Int = 0
    
    init(value: Int) {
        self.value = value
    }
    
    init(_ value: Int) {
        self.value = value
    }
    
    init() {}
    
    func merged(withSubordinate other: AccumulatingInt, commonAncestor: AccumulatingInt) throws -> AccumulatingInt {
        AccumulatingInt(value: value + other.value - commonAncestor.value)
    }
}
