import Foundation

actor LousyContestant {
    var intValue: Int = 0
    
    func addOne() async throws {
        let onEntry = intValue
        await pauseToTriggerRaceCondition()
        intValue = onEntry + 1
    }
    
    func result() async throws -> Int {
        intValue
    }
}
extension LousyContestant: Contestant {} 

