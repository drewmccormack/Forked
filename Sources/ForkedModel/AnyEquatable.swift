import Foundation

public struct ForkedEquatable: Equatable {
    private let value: Any
    private let equals: (Any) -> Bool
    
    public init?<T>(_ value: T) {
        return nil
    }

    public init?<T: Equatable>(_ value: T) {
        self.value = value
        self.equals = { other in
            guard let otherValue = other as? T else {
                return false
            }
            return value == otherValue
        }
    }

    public static func == (lhs: ForkedEquatable, rhs: ForkedEquatable) -> Bool {
        lhs.equals(rhs.value)
    }
}
