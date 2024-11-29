import Foundation
import Forked
import ForkedMerge

public typealias Mergeable = Forked.Mergeable

@attached(`extension`, names: arbitrary, conformances: Mergeable)
public macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
public macro Merged(using: PropertyMerge = .mergeableProtocol) = #externalMacro(module: "ForkedModelMacros", type: "MergeablePropertyMacro")

@attached(peer, names: arbitrary)
@attached(accessor, names: named(get), named(set))
public macro Backed(by: PropertyBacking = .mergeableValue) = #externalMacro(module: "ForkedModelMacros", type: "BackedPropertyMacro")
