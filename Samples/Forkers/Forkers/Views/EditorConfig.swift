import SwiftUI

struct EditorConfig {
    public var editingForker = Forker()
    public var isEditing: Bool = false
    
    mutating func beginEditing(forker: Forker) {
        editingForker = forker
        isEditing = true
    }
    
    public var canSave: Bool {
        !editingForker.firstName.isEmpty || !editingForker.lastName.isEmpty
    }
}
