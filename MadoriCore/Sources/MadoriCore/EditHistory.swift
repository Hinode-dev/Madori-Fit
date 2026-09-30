import Foundation

/// やり直し（Undo）と、やり直しの取り消し（Redo）の履歴。
///
/// 変更する前の状態を `record` で残す。`undo` は、直前の状態を返し、今の状態を Redo に回す。
public struct EditHistory<State> {
    public private(set) var undoStack: [State] = []
    public private(set) var redoStack: [State] = []
    /// 履歴の上限。古いものから捨てる。
    public let limit: Int

    public init(limit: Int = 100) {
        self.limit = limit
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// 変更する前の状態を残す。Redo は、消える。
    public mutating func record(_ before: State) {
        undoStack.append(before)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
    }

    /// 1 つ前の状態に戻す。戻すものがなければ nil。
    public mutating func undo(current: State) -> State? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    /// やり直しを取り消す。なければ nil。
    public mutating func redo(current: State) -> State? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
