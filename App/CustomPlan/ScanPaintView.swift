import SwiftUI
import LGKACore

/// The laser-game layer drawn over the camera: before the paper is fixed a white outline follows it;
/// then a grid lies on the paper in perspective, cells light up as they are scanned, a scan line
/// sweeps over the sheet and every value read pops up where it is printed.
struct ScanPaintView: View {
    let model: LiveScanModel
    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let camera = model.camera
            let sheet = model.sheet
            let quad = model.quad
            let coverage = model.coverage
            let litAt = model.cellLitAt
            let marks = model.marks
            let dimmed = model.hint != nil
            let finished = model.finished
            Canvas { context, size in
                guard let camera else { return }
                if let sheet {
                    drawSheet(&context, camera: camera, sheet: sheet, coverage: coverage, litAt: litAt,
                              marks: marks, now: now, dimmed: dimmed, finished: finished)
                } else if let quad, quad.count == 4 {
                    context.stroke(outline(quad), with: .color(.white), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                } else {
                    // a calm A4 frame until the paper is found
                    let width = size.width * 0.72, height = width * 297 / 210
                    let rect = CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2 - 20, width: width, height: height)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 14), with: .color(.white.opacity(0.7)),
                                   style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func outline(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    private func drawSheet(_ context: inout GraphicsContext, camera: CameraSnapshot, sheet: SheetFrame, coverage: [Float],
                           litAt: [Double], marks: [LiveScanModel.PinnedMark], now: Double, dimmed: Bool, finished: Bool) {
        let columns = SheetTracker.columns, rows = SheetTracker.rows
        // grid corners projected once
        var grid = [CGPoint?](repeating: nil, count: (columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                grid[row * (columns + 1) + column] = camera.project(sheet.world(Double(column) / Double(columns), Double(row) / Double(rows)))
            }
        }
        let paint = dimmed ? 0.4 : 1.0
        let lit = finished ? Color.green : accent

        for row in 0..<rows {
            for column in 0..<columns {
                let i = row * (columns + 1) + column
                guard let a = grid[i], let b = grid[i + 1], let c = grid[i + columns + 2], let d = grid[i + columns + 1] else { continue }
                let cell = outline([a, b, c, d])
                let score = Double(coverage.count > row * columns + column ? coverage[row * columns + column] : 0)
                if score >= 0.5 {
                    let age = now - litAt[row * columns + column]
                    context.fill(cell, with: .color(lit.opacity((0.12 + 0.2 * score) * paint)))
                    if !reduceMotion, age < 0.7 {
                        // fresh hit: a bright flash that fades
                        let flash = 1 - age / 0.7
                        context.fill(cell, with: .color(.white.opacity(0.55 * flash * paint)))
                        context.stroke(cell, with: .color(lit.opacity(flash * paint)), lineWidth: 1.5)
                    }
                } else {
                    context.stroke(cell, with: .color(.white.opacity(0.14 * paint)), lineWidth: 0.5)
                }
            }
        }

        // the paper's border
        if let tl = grid[0], let tr = grid[columns], let br = grid[(rows + 1) * (columns + 1) - 1], let bl = grid[rows * (columns + 1)] {
            context.stroke(outline([tl, tr, br, bl]), with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }

        // sweeping laser line
        if !reduceMotion, !finished {
            let v = (now / 2.4).truncatingRemainder(dividingBy: 1)
            if let left = camera.project(sheet.world(0, v)), let right = camera.project(sheet.world(1, v)) {
                var line = Path()
                line.move(to: left)
                line.addLine(to: right)
                context.stroke(line, with: .color(lit.opacity(0.9 * paint)), lineWidth: 2)
                context.stroke(line, with: .color(lit.opacity(0.25 * paint)), lineWidth: 10)
            }
        }

        // values where they are printed
        for mark in marks {
            guard let point = camera.project(sheet.world(mark.x, mark.y)) else { continue }
            let age = now - mark.seenAt
            switch mark.kind {
            case .subject:
                let dot = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.9 * paint)))
            case .value, .sum:
                let radius: CGFloat = mark.kind == .sum ? 7 : 5
                let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: dot.insetBy(dx: -4, dy: -4)), with: .color(lit.opacity(0.3 * paint)))
                context.fill(Path(ellipseIn: dot), with: .color(lit.opacity(paint)))
                if age < 1.6 || mark.kind == .sum {
                    // freshly read values pop up above their spot
                    let rise = reduceMotion ? 1 : min(1, age / 0.25)
                    let fade = mark.kind == .sum ? 1 : max(0, 1 - max(0, age - 1.1) / 0.5)
                    let label = Text(mark.text).font(.system(size: mark.kind == .sum ? 17 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    let resolved = context.resolve(label)
                    let labelSize = resolved.measure(in: CGSize(width: 200, height: 40))
                    let centre = CGPoint(x: point.x, y: point.y - 20 * rise)
                    let pill = CGRect(x: centre.x - labelSize.width / 2 - 7, y: centre.y - labelSize.height / 2 - 3,
                                      width: labelSize.width + 14, height: labelSize.height + 6)
                    context.opacity = fade * paint
                    context.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(lit))
                    context.draw(resolved, at: centre)
                    context.opacity = 1
                }
            }
        }
    }
}
