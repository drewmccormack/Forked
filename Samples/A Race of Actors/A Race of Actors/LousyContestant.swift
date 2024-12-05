import Foundation

actor LousyContestant {
    var intValue: Int = 0
    
    func addOne() async {
        let onEntry = intValue
        await pauseToTriggerRaceCondition()
        intValue = onEntry + 1
    }
    
    func result() -> Int {
        intValue
    }
}

extension LousyContestant: Contestant {} 
