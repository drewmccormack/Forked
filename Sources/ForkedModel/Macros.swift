import Foundation

@attached(peer)
macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ModelMacro")

@attached(accessor)
macro Merge() = #externalMacro(module: "ForkedModelMacros", type: "MergeMacro")
