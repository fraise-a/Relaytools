import Foundation

struct MazeLayout: Equatable, Sendable {
    static let cellSize = 3.4
    let size: Int
    let floors: Set<MazeCell>
    let start: MazeCell
    let exit: MazeCell
    let path: [MazeCell]
    let gates: [MazeCell]

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        let size = 13
        self.size = size
        start = .init(x: 1, z: 1)
        exit = .init(x: size - 2, z: size - 2)
        var random = MazeRandom(seed: seed)
        var floors: Set<MazeCell> = [start]
        var visited: Set<MazeCell> = [start]
        var stack = [start]
        let offsets = [(2, 0), (-2, 0), (0, 2), (0, -2)]
        while let current = stack.last {
            let choices = offsets.map { MazeCell(x: current.x + $0.0, z: current.z + $0.1) }
                .filter { $0.x > 0 && $0.x < size - 1 && $0.z > 0 && $0.z < size - 1 && !visited.contains($0) }
            guard let next = choices.randomElement(using: &random) else { stack.removeLast(); continue }
            floors.insert(.init(x: (current.x + next.x) / 2, z: (current.z + next.z) / 2))
            floors.insert(next)
            visited.insert(next)
            stack.append(next)
        }
        self.floors = floors
        let route = Self.route(in: floors, from: start, to: exit)
        path = route
        // These midpoint corridor cells are cut points in a perfect maze:
        // there is no alternate route around a closed customer gate.
        let corridorIndices = route.indices.filter { index in
            index > 2 && index < route.count - 2 &&
            ((route[index].x.isMultiple(of: 2)) != (route[index].z.isMultiple(of: 2)))
        }
        var chosen: [Int] = []
        for fraction in [0.24, 0.51, 0.78] {
            let target = Int(Double(route.count - 1) * fraction)
            if let index = corridorIndices.filter({ candidate in chosen.allSatisfy { abs($0 - candidate) >= 3 } })
                .min(by: { abs($0 - target) < abs($1 - target) }) {
                chosen.append(index)
            }
        }
        gates = chosen.sorted().map { route[$0] }
    }

    func world(_ cell: MazeCell) -> MazePoint {
        .init(x: Double(cell.x) * Self.cellSize, z: Double(cell.z) * Self.cellSize)
    }
    func cell(at point: MazePoint) -> MazeCell {
        .init(x: Int(floor(point.x / Self.cellSize + 0.5)), z: Int(floor(point.z / Self.cellSize + 0.5)))
    }
    func canOccupy(_ point: MazePoint, closedGates: Set<MazeCell>, radius: Double = 0.27) -> Bool {
        for offset in [(-radius, -radius), (radius, -radius), (-radius, radius), (radius, radius)] {
            let cell = cell(at: .init(x: point.x + offset.0, z: point.z + offset.1))
            if !floors.contains(cell) || closedGates.contains(cell) { return false }
        }
        return true
    }

    static func route(in floors: Set<MazeCell>, from start: MazeCell, to exit: MazeCell) -> [MazeCell] {
        guard floors.contains(start), floors.contains(exit) else { return [] }
        var queue = [start]
        var cursor = 0
        var seen: Set<MazeCell> = [start]
        var previous: [MazeCell: MazeCell] = [:]
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            if current == exit { break }
            for (x, z) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let next = MazeCell(x: current.x + x, z: current.z + z)
                if floors.contains(next) && seen.insert(next).inserted {
                    previous[next] = current
                    queue.append(next)
                }
            }
        }
        guard seen.contains(exit) else { return [] }
        var result = [exit]
        while let parent = previous[result.last!] { result.append(parent) }
        return result.reversed()
    }
}

private struct MazeRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
