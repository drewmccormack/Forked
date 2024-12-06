import Foundation
import Forked

struct AccumulatingInt: Mergeable {
    var value: Int
    func merged(withSubordinate other: AccumulatingInt, commonAncestor: AccumulatingInt) throws -> AccumulatingInt {
        AccumulatingInt(value: value + other.value - commonAncestor.value)
    }
}

actor ForkingContestant {
    let forkedInt = QuickFork<AccumulatingInt>()
    
    init() {
        try! forkedInt.update(.main, with: .init(value: 0))
    }

}

extension ForkingContestant: Contestant {
    
    func addOne() async throws {
        let fork = Fork(name: UUID().uuidString)
        try forkedInt.create(fork)
        try forkedInt.syncMain(with: [fork])
        
        var accumulatingInt = try forkedInt.value(in: fork)!
        await pauseToTriggerRaceCondition()
        accumulatingInt.value += 1
        try forkedInt.update(fork, with: accumulatingInt)
        
        try forkedInt.mergeIntoMain(from: fork)
        try forkedInt.delete(fork)
    }
    
    func result() throws -> Int {
        try forkedInt.syncAllForks()
        return try forkedInt.value(in: .main)!.value
    }
    
}

