import Foundation

protocol Contestant {
    func addOne() async throws
    func result() async throws -> Int
}

func pauseToTriggerRaceCondition() async {
    if Float.random(in: 0...1) > 0.8 {
        try! await Task.sleep(for: .milliseconds(Int.random(in: 1...100)))
    }
}

func countTo100(using contestant: some Contestant) async -> Int {
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask {
                try! await contestant.addOne()
            }
        }
        await group.waitForAll()
    }
    
    let result = try! await contestant.result()
    print("Final count: \(result)")
    return result
}
