import Foundation

public final class Store {
    public var state: AppState
    private let url: URL
    private var saveWork: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.macfocusos.store")

    public init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("MacFocusOS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("state.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            state = decoded
        } else {
            state = AppState()
        }
    }

    public func save() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let data = try? JSONEncoder().encode(self.state) {
                try? data.write(to: self.url, options: .atomic)
            }
        }
        saveWork = work
        queue.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}
