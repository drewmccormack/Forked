import Foundation

public typealias QuickFork<T: Equatable> = ForkedResource<AtomicRepository<T>>

public extension QuickFork {
    
    /// Convenience for creating simple forked resource for in-memory use.
    /// Create an in-memory ForkedResource with the given forks, and initial value.
    /// The initial value is optional. If not provided, the main fork will be empty.
    /// The setup ensures that all forks are synced up with the initial value, which is different to
    /// the default behavior when you first create a ForkedResource. (In a forked resource,
    /// a new fork is initially empty, and may not be in sync with the main fork until merged.)
    convenience init<R>(initialValue: R? = nil, forks: [Fork]) where RepositoryType == AtomicRepository<R> {
        do {
            let repository = AtomicRepository<R>()
            try self.init(repository: repository)
            
            if let initialValue {
                try update(.main, with: initialValue)
            }
            
            for fork in forks {
                try? create(fork)
            }
            
            try syncAllForks()
        } catch {
            fatalError("Failed to create ForkedResource: \(error)")
        }
    }
    
    /// Convenience for creating simple forked resource for in-memory use.
    /// Create an in-memory ForkedResource with the given fork names, and initial value.
    /// The setup ensures that all forks are synced up with the initial value — if there is one —
    /// which is different to the default behavior when you first create a ForkedResource. (In a forked resource,
    /// a new fork is initially empty, and may not be in sync with the main fork until merged.)
    convenience init<R>(initialValue: R? = nil, forkNames: [String] = []) where RepositoryType == AtomicRepository<R> {
        self.init(initialValue: initialValue, forks: forkNames.map(Fork.init))
    }
    
}
