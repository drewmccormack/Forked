import Foundation

protocol Contestant {
    func addOne() async
    func result() async -> Int
}

func pauseToTriggerRaceCondition() async {
    if Float.random(in: 0...1) > 0.5 {
        try! await Task.sleep(for: .milliseconds(Int.random(in: 1...100)))
    }
}

func countTo100(using contestant: some Contestant) async -> Int {
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask {
                await contestant.addOne()
            }
        }
        await group.waitForAll()
    }
    
    let result = await contestant.result()
    print("Final count: \(result)")
    return result
}
