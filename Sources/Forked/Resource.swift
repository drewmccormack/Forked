import Foundation

/// This protocol is attached to any type you want to store in a `ForkedResource`.
/// It is a marker protcol, with no requirements.
public protocol Resource {}

extension Int: Resource {}
extension String: Resource {}
extension Data: Resource {}
