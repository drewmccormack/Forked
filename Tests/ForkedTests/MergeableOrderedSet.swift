import Testing
@testable import ForkedMerge

struct MergeableOrderedSetSuite {
    
    @Test func insertAndRemove() {
        var set = MergeableOrderedSet<String>()
        
        let success1 = set.insert("a", at: 0)
        #expect(success1)
        let success2 = set.insert("b", at: 1)
        #expect(success2)
        let success3 = set.insert("c", at: 2)
        #expect(success3)
        #expect(set.values == ["a", "b", "c"])
        
        let success4 = set.insert("x", at: 0)
        #expect(success4)
        #expect(set.values == ["x", "a", "b", "c"])
        
        let success5 = set.insert("y", at: 2)
        #expect(success5)
        #expect(set.values == ["x", "a", "y", "b", "c"])
        
        let removed1 = set.remove("a")
        #expect(removed1 == "a")
        #expect(set.values == ["x", "y", "b", "c"])
        
        let removed2 = set.remove("z")
        #expect(removed2 == nil)
        let removed3 = set.remove("a")
        #expect(removed3 == nil)
    }
    
    @Test func moveElements() {
        var set = MergeableOrderedSet<String>()
        set.insert("a", at: 0)
        set.insert("b", at: 1)
        set.insert("c", at: 2)
        #expect(set.values == ["a", "b", "c"])
        
        // Moving forward: when moving from index 0 to 2,
        // it ends up before the element that was at index 2
        // because removing "a" first shifts everything down
        set.move("a", toIndex: 2)
        #expect(set.values == ["b", "a", "c"])
        
        // Moving backward: when moving from a later index to an earlier one,
        // the target index is exactly where it ends up because
        // the removal happens after the insertion position is determined
        set.move("c", toIndex: 0)
        #expect(set.values == ["c", "b", "a"])
        
        // Moving to current index (no change)
        set.move("b", toIndex: 1)
        #expect(set.values == ["c", "b", "a"])
        
        // Moving non-existent element (no change)
        set.move("x", toIndex: 0)
        #expect(set.values == ["c", "b", "a"])
    }
    
    @Test func mergeWithConflicts() {
        var set1 = MergeableOrderedSet<String>()
        var set2 = MergeableOrderedSet<String>()
        
        set1.insert("a", at: 0)
        set1.insert("b", at: 1)
        set1.insert("c", at: 2)
        
        set2.insert("a", at: 0)
        set2.insert("b", at: 1)
        set2.insert("d", at: 2)
        
        set1.move("a", toIndex: 2)
        set2.move("b", toIndex: 0)

        set1.remove("b")
        set2.remove("a")
        
        let merged = try! set1.merged(with: set2)
        
        #expect(merged.values.count == 2)
        #expect(merged.contains("c"))
        #expect(merged.contains("d"))
        #expect(!merged.contains("a"))
        #expect(!merged.contains("b"))
    }
    
    @Test func priorityNormalization() {
        var set = MergeableOrderedSet<String>()
        
        for i in 0..<100 {
            set.insert(String(i), at: 0)
        }
        
        #expect(set.values == (0..<100).map(String.init).reversed())
        
        set.insert("x", at: 50)
        #expect(set.values[50] == "x")
    }
    
    @Test func arrayLiteralInitialization() {
        let set: MergeableOrderedSet<String> = ["a", "b", "c"]
        #expect(set.values == ["a", "b", "c"])
    }
    
    @Test func valuesPropertyOperations() {
        var set = MergeableOrderedSet<String>()
        
        set.values = ["a", "b", "c"]
        #expect(set.values == ["a", "b", "c"])
        
        set.values = ["c", "a", "b"]
        #expect(set.values == ["c", "a", "b"])
        
        set.values = ["d", "b", "e"]
        #expect(set.values == ["d", "b", "e"])
        #expect(!set.contains("a"))
        #expect(!set.contains("c"))
        #expect(set.contains("d"))
        #expect(set.contains("e"))
    }
    
    @Test func mergePreservesOrder() {
        var set1 = MergeableOrderedSet<String>()
        var set2 = MergeableOrderedSet<String>()
        
        // Set up initial states with same elements in different orders
        set1.insert("a", at: 0)
        set1.insert("b", at: 1)
        set1.insert("c", at: 2)
        
        set2.insert("c", at: 0)
        set2.insert("a", at: 1)
        set2.insert("b", at: 2)
        
        // Modify both sets
        set1.move("a", toIndex: 2)  // ["b", "c", "a"]
        set2.move("b", toIndex: 0)  // ["b", "c", "a"]
        
        // Merge both ways
        let merged1 = try! set1.merged(with: set2)
        let merged2 = try! set2.merged(with: set1)
        
        // Check that order is preserved based on most recent operations
        #expect(merged1.values == ["b", "c", "a"])
        
        // Check that merge is symmetric
        #expect(merged1.values == merged2.values)
    }
    
    @Test func mergeIsAssociative() {
        var set1 = MergeableOrderedSet<String>()
        var set2 = MergeableOrderedSet<String>()
        var set3 = MergeableOrderedSet<String>()
        
        // Set up different initial states
        set1.insert("a", at: 0)
        set1.move("a", toIndex: 1)
        
        set2.insert("b", at: 0)
        set2.move("b", toIndex: 1)
        
        set3.insert("c", at: 0)
        set3.insert("d", at: 1)
        
        // Test (set1 ∪ set2) ∪ set3 == set1 ∪ (set2 ∪ set3) for membership
        let merged1 = try! set1.merged(with: set2)
        let result1 = try! merged1.merged(with: set3)
        
        let merged2 = try! set2.merged(with: set3)
        let result2 = try! set1.merged(with: merged2)
        
        // Check set membership is associative
        let set1Elements = Set(result1.values)
        let set2Elements = Set(result2.values)
        #expect(set1Elements == set2Elements)
        
        // Check that performing the same merges again produces the same results
        // (deterministic ordering)
        let result1Again = try! set1.merged(with: set2).merged(with: set3)
        let result2Again = try! set1.merged(with: set2.merged(with: set3))
        #expect(result1.values == result1Again.values)
        #expect(result2.values == result2Again.values)
    }
    
    @Test func mergeIsCommutative() {
        var set1 = MergeableOrderedSet<String>()
        var set2 = MergeableOrderedSet<String>()
        
        // Set up different initial states and operations
        set1.insert("a", at: 0)
        set1.insert("b", at: 1)
        set1.move("a", toIndex: 1)
        
        set2.insert("b", at: 0)
        set2.insert("c", at: 1)
        set2.move("c", toIndex: 0)
        
        let merged1 = try! set1.merged(with: set2)
        let merged2 = try! set2.merged(with: set1)
        
        #expect(merged1.values == merged2.values)
    }
    
    @Test func mergeIsIdempotent() {
        var set = MergeableOrderedSet<String>()
        
        set.insert("a", at: 0)
        set.insert("b", at: 1)
        
        var set2 = set
        set2.move("a", toIndex: 1)
        set2.insert("c", at: 0)
        
        let merged = try! set.merged(with: set2)
        let merged2 = try! set.merged(with: merged).merged(with: set2)

        #expect(merged2.values == merged.values)
    }
} 
