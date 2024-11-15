import Foundation

@attached(peer)
macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(peer)
macro ForkedProperty() = #externalMacro(module: "ForkedModelMacros", type: "ForkedPropertyMacro")
