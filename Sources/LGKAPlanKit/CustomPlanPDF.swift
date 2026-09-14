import Foundation
import CoreGraphics
import CoreText
import LGKACore

/// Draws a `CustomPlan` as an A4 landscape PDF in the Untis look: header with school, year and
/// name, Mo–Fr × 11 periods with times, heavy lines between the double-period blocks, and per
/// lesson the course in bold, the teacher and the room in italics.
public enum CustomPlanPDF {
    public static func render(_ plan: CustomPlan) -> Data {
        let data = NSMutableData()
        let width: CGFloat = 841.89, height: CGFloat = 595.28
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        let info = [kCGPDFContextTitle: "Stundenplan \(plan.name) – \(plan.stufe) \(plan.halbjahr) \(plan.schuljahr ?? "")"
            as CFString] as CFDictionary
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, info) else { return Data() }
        ctx.beginPDFPage(nil)
        Page(ctx: ctx, width: width, height: height).draw(plan)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    private struct Page {
        let ctx: CGContext
        let width: CGFloat
        let height: CGFloat

        enum Align { case left, centre, right }

        func draw(_ plan: CustomPlan) {
            let W = width, H = height
            let black = CGColor(gray: 0, alpha: 1)
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

            // header
            text("Lessing-Gymnasium Karlsruhe", bold(11), 30, H - 32)
            if let schuljahr = plan.schuljahr { text("Schuljahr \(schuljahr)", regular(10), 240, H - 32) }
            text("D-76135, Sophienstr. 147", regular(10), 30, H - 45)
            text(plan.name.isEmpty ? "Persönlicher Stundenplan" : plan.name, bold(11), W - 30, H - 32, .right)
            let meta = [plan.stufe, plan.halbjahr, plan.stand.map { "Stand \($0)" }].compactMap { $0 }
            text(meta.joined(separator: " · "), regular(9), W - 30, H - 45, .right)
            text(plan.stufe, bold(18), 30, H - 72)
            text("Persönlicher Stundenplan", regular(14), 70, H - 72)

            // grid
            let periods = plan.periods.count
            let x0: CGFloat = 30, y0 = H - 88
            let labelWidth: CGFloat = 62
            let columnWidth = (W - 60 - labelWidth) / 5
            let headHeight: CGFloat = 26
            let rowHeight = (y0 - headHeight - 30) / CGFloat(periods)
            let gx = x0 + labelWidth
            let gy = y0 - headHeight
            let bottom = gy - rowHeight * CGFloat(periods)

            ctx.setStrokeColor(black)
            ctx.setLineWidth(1.4)
            ctx.stroke(CGRect(x: x0, y: bottom, width: W - 60, height: headHeight + rowHeight * CGFloat(periods)))
            line(gx, y0, gx, bottom)
            line(x0, gy, x0 + W - 60, gy)
            for (i, day) in CustomPlan.dayNames.enumerated() {
                let xx = gx + CGFloat(i) * columnWidth
                if i > 0 { line(xx, y0, xx, bottom) }
                text(day, bold(13), xx + columnWidth / 2, gy + 8, .centre)
            }

            for (index, period) in plan.periods.enumerated() {
                let p = index + 1
                let yy = gy - CGFloat(index) * rowHeight
                text("\(period.number)", bold(11), x0 + labelWidth / 2, yy - rowHeight / 2 + 1, .centre)
                text("\(period.start)–\(period.end)", regular(6.8), x0 + labelWidth / 2, yy - rowHeight / 2 - 9, .centre)
                if p > 1 {
                    let heavy = SchoolReference.blockStarts.contains(p)
                    ctx.setLineWidth(heavy ? 1.0 : 0.4)
                    ctx.setStrokeColor(heavy ? black : CGColor(gray: 0.6, alpha: 1))
                    line(x0 + (heavy ? 0 : labelWidth), yy, x0 + W - 60, yy)
                }
            }
            ctx.setStrokeColor(black)

            // lessons: white-out the cell (hides the light line inside a double period), then the text
            for lesson in plan.lessons {
                guard let course = plan.courses.first(where: { $0.id == lesson.course }) else { continue }
                let xx = gx + CGFloat(lesson.day) * columnWidth
                let top = gy - CGFloat(lesson.start - 1) * rowHeight
                let bot = gy - CGFloat(lesson.end) * rowHeight
                ctx.setFillColor(CGColor(gray: 1, alpha: 1))
                ctx.fill(CGRect(x: xx + 1, y: bot + 1, width: columnWidth - 2, height: top - bot - 2))
                let cy = (top + bot) / 2
                let fit = columnWidth - 8
                text(course.title, bold(9.2), xx + columnWidth / 2, cy + 6, .centre, maxWidth: fit)
                text(course.teacherLabel, regular(8.5), xx + columnWidth / 2, cy - 4, .centre, maxWidth: fit)
                if !lesson.rooms.isEmpty {
                    text("Raum \(lesson.roomLabel)", italic(8.5), xx + columnWidth / 2, cy - 14, .centre, maxWidth: fit)
                }
            }

            let pauses = plan.breaks.map { "\($0.start)–\($0.end)" }.joined(separator: " · ")
            var foot = "\(SchoolReference.laeuteordnungSource). Große Pausen: \(pauses)"
            if !plan.notes.isEmpty { foot += " · " + plan.notes.joined(separator: " · ") }
            text(foot, regular(7), 30, 18, maxWidth: W - 60)
        }

        private func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            ctx.move(to: CGPoint(x: x1, y: y1))
            ctx.addLine(to: CGPoint(x: x2, y: y2))
            ctx.strokePath()
        }

        private func regular(_ size: CGFloat) -> CTFont { CTFontCreateWithName("Helvetica" as CFString, size, nil) }
        private func bold(_ size: CGFloat) -> CTFont { CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil) }
        private func italic(_ size: CGFloat) -> CTFont { CTFontCreateWithName("Helvetica-Oblique" as CFString, size, nil) }

        private func text(_ string: String, _ font: CTFont, _ x: CGFloat, _ y: CGFloat,
                          _ align: Align = .left, maxWidth: CGFloat? = nil) {
            var font = font
            var line = makeLine(string, font)
            var lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            if let maxWidth, lineWidth > maxWidth {
                // long subject names shrink instead of running into the next day
                font = CTFontCreateCopyWithAttributes(font, CTFontGetSize(font) * maxWidth / lineWidth, nil, nil)
                line = makeLine(string, font)
                lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            }
            let originX: CGFloat = switch align {
            case .left: x
            case .centre: x - lineWidth / 2
            case .right: x - lineWidth
            }
            ctx.textPosition = CGPoint(x: originX, y: y)
            CTLineDraw(line, ctx)
        }

        private func makeLine(_ string: String, _ font: CTFont) -> CTLine {
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        }
    }
}
