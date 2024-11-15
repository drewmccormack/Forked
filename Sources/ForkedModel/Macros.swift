import Foundation

@attached(peer, names: prefixed(forkedmodel_))
macro ForkedModel() = #externalMacro(module: "ForkedModelMacros", type: "ForkedModelMacro")

@attached(accessor, names: prefixed(forkedproperty_))
macro ForkedProperty() = #externalMacro(module: "ForkedModelMacros", type: "ForkedPropertyMacro")
