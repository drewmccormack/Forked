@_exported import Forked
@_exported import ForkedMerge

import Foundation

public typealias Mergeable = Forked.Mergeable

@attached(`extension`, conformances: Mergeable, VersionedModel, names: arbitrary)
@attached(member, names: arbitrary)
public macro ForkedModel(version: Int? = nil) = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
public macro Merged(using: PropertyMerge = .mergeableProtocol) = #externalMacro(module: "ForkedModelMacros", type: "MergeablePropertyMacro")

@attached(peer, names: arbitrary)
@attached(accessor, names: named(get), named(set))
public macro Backed(by: PropertyBacking = .mergeableValue) = #externalMacro(module: "ForkedModelMacros", type: "BackedPropertyMacro")
