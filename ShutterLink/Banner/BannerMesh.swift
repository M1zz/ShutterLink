import RealityKit
import simd

/// Shape of a banner held at both ends: it droops in the middle, hangs in soft vertical folds,
/// pulls into diagonal wrinkles toward the held corners and, if fluttering, ripples in a light breeze.
struct ClothShape {
    var width: Float
    var height: Float
    var sag: Float
    /// Scales the folds and wrinkles; 0 is a flat sheet.
    var wrinkle: Float
    /// Breeze strength; 0 keeps the cloth still.
    var wind: Float = 0

    static let columns = 64
    static let rows = 16

    /// Point on the cloth at `u` (0 left … 1 right) and `v` (0 top … 1 bottom), `time` in seconds.
    func point(u: Float, v: Float, time: Float) -> SIMD3<Float> {
        let held = sin(u * .pi)                       // 0 at the poles, 1 in the middle
        let x = (u - 0.5) * width
        // Whole banner droops between the two hands, a little more along the free bottom edge.
        let droop = -sag * held * (1 + 0.25 * v)
        let y = (0.5 - v) * height + droop

        // Soft vertical folds, deeper toward the bottom where the cloth hangs free.
        var z = sag * 0.75 * wrinkle * sin(u * .pi * 6 + 0.6) * held * (0.25 + 0.75 * v)
        // Diagonal pull wrinkles fanning out from each held corner.
        for (side, corner) in [(Float(0), Float(0)), (1, 0), (0, 1), (1, 1)] {
            let du = abs(u - side) * width
            let dv = abs(v - corner) * height
            let reach: Float = exp(-du / (height * 0.9))
            let angle: Float = (side == 0 ? 1 : -1) * (corner == 0 ? 1 : -1)
            let phase: Float = (du * 0.9 + dv * angle) / 0.03
            z += 0.018 * wrinkle * reach * sin(phase)
        }
        // Breeze: two travelling waves, held still at the poles.
        if wind > 0 {
            let gust: Float = sin(time * 0.9) * 0.5 + 0.5
            let swell: Float = 0.030 * sin(u * .pi * 2.2 - time * 2.1)
            let ripple: Float = 0.012 * sin(u * .pi * 5.0 - time * 3.3 + v * 1.5) * gust
            z += wind * held * (0.6 + 0.4 * v) * (swell + ripple)
        }
        return [x, y, z]
    }

    func meshDescriptor(time: Float = 0) -> MeshDescriptor {
        let columns = Self.columns, rows = Self.rows
        var grid: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        grid.reserveCapacity((columns + 1) * (rows + 1))
        uvs.reserveCapacity(grid.capacity)
        for r in 0 ... rows {
            for c in 0 ... columns {
                let u = Float(c) / Float(columns)
                let v = Float(r) / Float(rows)
                grid.append(point(u: u, v: v, time: time))
                uvs.append([u, 1 - v]) // RealityKit UV origin is bottom-left
            }
        }

        // Normals from the actual surface, so folds catch the light instead of shading flat.
        let stride = columns + 1
        var normals: [SIMD3<Float>] = []
        normals.reserveCapacity(grid.count)
        for r in 0 ... rows {
            for c in 0 ... columns {
                let left = grid[r * stride + max(c - 1, 0)]
                let right = grid[r * stride + min(c + 1, columns)]
                let up = grid[max(r - 1, 0) * stride + c]
                let down = grid[min(r + 1, rows) * stride + c]
                // Across goes +X, down goes -Y: (down × across) faces the viewer (+Z).
                normals.append(simd_normalize(simd_cross(down - up, right - left)))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(columns * rows * 6)
        let s = UInt32(stride)
        for r in 0 ..< rows {
            for c in 0 ..< columns {
                let tl = UInt32(r) * s + UInt32(c)
                let tr = tl + 1
                let bl = tl + s
                let br = bl + 1
                // Counter-clockwise as seen from the front (+Z).
                indices += [tl, bl, br, tl, br, tr]
            }
        }

        var descriptor = MeshDescriptor(name: "banner")
        descriptor.positions = MeshBuffer(grid)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return descriptor
    }
}
