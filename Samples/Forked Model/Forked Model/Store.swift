import Foundation
import Forked
import ForkedMerge
import ForkedModel
import SwiftUI

/// Mergeable type that accumulates the changes to each fork.
struct AccumulatingInt: Mergeable {
    var value: Int = 0
    func merged(withSubordinate other: AccumulatingInt, commonAncestor: AccumulatingInt) throws -> AccumulatingInt {
        return AccumulatingInt(value: self.value + other.value - (commonAncestor?.value ?? 0))
    }
}

@ForkedModel
struct Model {
    @Merged(using: .textMerge) var text: String = "Change this text"
    @Merged var count: AccumulatingInt = .init()
}

extension Fork {
    static let ui1 = Fork(name: "ui1")
    static let ui2 = Fork(name: "ui2")
}

@MainActor
@Observable
class Store {
    @ObservationIgnored
    let forkedModel = QuickFork<Model>(initialValue: Model(), forks: [.ui1, .ui2])

    public var displayedText1: String {
        didSet {
            var model = try! forkedModel.resource(of: .ui1)!
            guard displayedText1 != model.text else { return }
            model.text = displayedText1
            try! forkedModel.update(.ui1, with: model)
        }
    }
    
    public var displayedText2: String {
        didSet {
            var model = try! forkedModel.resource(of: .ui2)!
            guard displayedText2 != model.text else { return }
            model.text = displayedText2
            try! forkedModel.update(.ui2, with: model)
        }
    }
    
    public var displayedCount1: Int {
        didSet {
            var model = try! forkedModel.resource(of: .ui1)!
            guard displayedCount1 != model.count.value else { return }
            model.count.value = displayedCount1
            try! forkedModel.update(.ui1, with: model)
        }
    }
    
    public var displayedCount2: Int {
        didSet {
            var model = try! forkedModel.resource(of: .ui2)!
            guard displayedCount2 != model.count.value else { return }
            model.count.value = displayedCount2
            try! forkedModel.update(.ui2, with: model)
        }
    }
    
    init() {
        displayedText1 = try! forkedModel.resource(of: .ui1)!.text
        displayedText2 = try! forkedModel.resource(of: .ui2)!.text
        displayedCount1 = try! forkedModel.resource(of: .ui1)!.count.value
        displayedCount2 = try! forkedModel.resource(of: .ui2)!.count.value
    }
    
    public func merge() {
        try! forkedModel.syncAllForks()
        displayedText1 = try! forkedModel.resource(of: .ui1)!.text
        displayedText2 = try! forkedModel.resource(of: .ui2)!.text
        displayedCount1 = try! forkedModel.resource(of: .ui1)!.count.value
        displayedCount2 = try! forkedModel.resource(of: .ui2)!.count.value
    }
}
