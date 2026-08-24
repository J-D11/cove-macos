import Foundation

struct ClipboardSmartAction: Identifiable {
    enum Operation {
        case open(URL)
        case copy(String)
        case paste(String)
    }

    let id: String
    let title: String
    let symbolName: String
    let operation: Operation
}
