/// Unsupported and empty saved selections use the current provider default.
enum ModelSelection {
    static func resolve(_ savedID: String, availableIDs: [String], defaultID: String) -> String {
        !savedID.isEmpty && availableIDs.contains(savedID) ? savedID : defaultID
    }
}
