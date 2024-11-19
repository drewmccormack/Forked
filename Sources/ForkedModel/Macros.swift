import Foundation
import Forked
import ForkedMerge

public typealias Mergable = Forked.Mergable

@attached(`extension`, names: arbitrary, conformances: Mergable)
public macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
@attached(accessor)
public macro ForkedProperty(mergeWith: PropertyMergeAlgorithm = .mergable) = #externalMacro(module: "ForkedModelMacros", type: "ForkedPropertyMacro")
