
public struct TextMerger: Merger {
    
    public init() {}
    
    public func merge(_ value: String, withOlderConflicting other: String, commonAncestor: String?) throws -> String {
        let valueChars = Array(value)
        let otherChars = Array(other)
        let commonAncestorChars = commonAncestor.flatMap { Array($0) }
        let valueArrayMerger = ValueArrayMerger<String.Element>()
        let mergedChars = try valueArrayMerger.merge(valueChars, withOlderConflicting: otherChars, commonAncestor: commonAncestorChars)
        return String(mergedChars)
    }
    
}
