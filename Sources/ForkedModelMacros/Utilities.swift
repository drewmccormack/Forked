import Foundation

internal func extractKeyAndValueTypes(from originalType: String) -> (keyType: String, valueType: String)? {
    // Check for [Key: Value] syntax
    if originalType.hasPrefix("[") && originalType.hasSuffix("]") {
        guard let colonRange = originalType.range(of: ":") else { return nil }
        let keyType = originalType[originalType.index(after: originalType.startIndex)..<colonRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueType = originalType[colonRange.upperBound..<originalType.index(before: originalType.endIndex)].trimmingCharacters(in: .whitespacesAndNewlines)
        return (keyType, valueType)
    }
    
    // Check for Dictionary<Key, Value> syntax
    if originalType.hasPrefix("Dictionary<") && originalType.hasSuffix(">") {
        let innerTypes = originalType.dropFirst("Dictionary<".count).dropLast()
        let components = innerTypes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
    }
    
    // Not a valid dictionary type
    return nil
}
