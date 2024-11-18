import Foundation
import ForkedModelMacros

@attached(peer)
macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
macro ForkedProperty(mergeAlgorithm: MergeAlgorithm = .property) = #externalMacro(module: "ForkedModelMacros", type: "ForkedPropertyMacro")
