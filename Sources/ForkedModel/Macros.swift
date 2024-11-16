import Foundation
import ForkedModelMacros

@attached(peer)
macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
macro ForkedProperty(mergeAlgorithm: MergeAlgorithm = .mergablePropertyAlgorithm) = #externalMacro(module: "ForkedModelMacros", type: "ForkedPropertyMacro")
