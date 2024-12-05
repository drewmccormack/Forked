
public struct TextMerger: Merger {
    
    public init() {}
    
    public func merge(_ value: String, withSubordinate other: String, commonAncestor: String) throws -> String {
        let valueChars = Array(value)
        let otherChars = Array(other)
        let commonAncestorChars = Array(commonAncestor)
        let arrayMerger = ArrayMerger<String.Element>()
        let mergedChars = try arrayMerger.merge(valueChars, withSubordinate: otherChars, commonAncestor: commonAncestorChars)
        return String(mergedChars)
    }
    
}
