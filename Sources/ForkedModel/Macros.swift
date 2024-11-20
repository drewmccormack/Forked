import Foundation
import Forked
import ForkedMerge

public typealias Mergable = Forked.Mergable

@attached(`extension`, names: arbitrary, conformances: Mergable)
public macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
public macro Merged(using: PropertyMerge = .mergableProtocol) = #externalMacro(module: "ForkedModelMacros", type: "MergablePropertyMacro")

@attached(peer, names: arbitrary)
@attached(accessor, names: named(get), named(set))
public macro Backed(by: PropertyBacking = .register) = #externalMacro(module: "ForkedModelMacros", type: "BackedPropertyMacro")
