import os

nonisolated enum Log {
    static let spotify = Logger(subsystem: "com.valerioceniccola.atollo", category: "spotify")
    static let mediaKeys = Logger(subsystem: "com.valerioceniccola.atollo", category: "mediakeys")
}
