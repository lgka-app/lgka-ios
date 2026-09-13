import SwiftUI

/// New Year's Day fireworks — mirrors fireworks_overlay.dart + provider
/// (visible on January 1st, Europe/Berlin). Respects Reduce Motion.
struct FireworksOverlay: View {
    @State private var isNewYear = isNewYearsDay()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func isNewYearsDay() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let comps = cal.dateComponents([.month, .day], from: Date())
        return comps.month == 1 && comps.day == 1
    }

    var body: some View {
        Group {
            if isNewYear && !reduceMotion {
                FireworksCanvas()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                isNewYear = Self.isNewYearsDay()
            }
        }
    }
}

/// Rockets rise from the bottom edge, burst near the top and fall apart with
/// drag, gravity and short tails. Several bursts overlap.
private struct FireworksCanvas: View {
    @State private var sim = FireworksSimulation()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                sim.advance(to: timeline.date, in: size)
                sim.draw(in: &context, glow: colorScheme == .dark)
            }
        }
    }
}

@MainActor
private final class FireworksSimulation {
    private struct Rocket {
        var position: CGPoint
        var velocity: CGVector
        let color: Color
    }

    private struct Spark {
        var position: CGPoint
        var velocity: CGVector
        var trail: [CGPoint] = []
        var age: Double = 0
        let life: Double
        let radius: CGFloat
        let color: Color
        let twinkle: Bool
        let drag: Double
        let gravity: Double
    }

    private struct Flash {
        let center: CGPoint
        var age: Double = 0
        let color: Color
    }

    // the Flutter palette, a touch brighter so it glows on the dark background
    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.30, blue: 0.30), // red
        Color(red: 0.35, green: 0.62, blue: 1.00), // blue
        Color(red: 0.35, green: 0.95, blue: 0.50), // green
        Color(red: 0.78, green: 0.45, blue: 1.00), // purple
        Color(red: 1.00, green: 0.62, blue: 0.20), // orange
        Color(red: 1.00, green: 0.90, blue: 0.30), // yellow
        Color(red: 1.00, green: 0.45, blue: 0.75), // pink
    ]

    private var rockets: [Rocket] = []
    private var sparks: [Spark] = []
    private var flashes: [Flash] = []
    private var lastDate: Date?
    private var nextLaunchIn: Double = 0.2

    func advance(to date: Date, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        // clamp so a frame after the app was in the background does not jump
        let dt = min(date.timeIntervalSince(lastDate ?? date), 1.0 / 30.0)
        lastDate = date

        nextLaunchIn -= dt
        if nextLaunchIn <= 0 {
            launch(in: size)
            if Double.random(in: 0...1) < 0.2 { launch(in: size) } // now and then a pair
            nextLaunchIn = .random(in: 0.8...1.8)
        }

        for i in rockets.indices.reversed() {
            rockets[i].velocity.dy += 430 * dt
            rockets[i].position.x += rockets[i].velocity.dx * dt
            rockets[i].position.y += rockets[i].velocity.dy * dt
            let rocket = rockets[i]
            // the rising spark trail
            for _ in 0..<2 {
                sparks.append(Spark(
                    position: rocket.position,
                    velocity: CGVector(dx: .random(in: -18...18), dy: .random(in: 20...60)),
                    life: .random(in: 0.25...0.5), radius: .random(in: 0.8...1.4),
                    color: Color(red: 1, green: 0.85, blue: 0.6), twinkle: false, drag: 3, gravity: 40))
            }
            if rocket.velocity.dy > -35 {
                explode(rocket)
                rockets.remove(at: i)
            }
        }

        for i in sparks.indices.reversed() {
            sparks[i].age += dt
            if sparks[i].age >= sparks[i].life {
                sparks.remove(at: i)
                continue
            }
            let damping = exp(-sparks[i].drag * dt)
            sparks[i].velocity.dx *= damping
            sparks[i].velocity.dy = sparks[i].velocity.dy * damping + sparks[i].gravity * dt
            sparks[i].trail.append(sparks[i].position)
            if sparks[i].trail.count > 9 { sparks[i].trail.removeFirst() }
            sparks[i].position.x += sparks[i].velocity.dx * dt
            sparks[i].position.y += sparks[i].velocity.dy * dt
        }

        for i in flashes.indices.reversed() {
            flashes[i].age += dt
            if flashes[i].age > 0.45 { flashes.remove(at: i) }
        }
    }

    private func launch(in size: CGSize) {
        let start = CGPoint(x: size.width * .random(in: 0.15...0.85), y: size.height + 10)
        let apex = size.height * .random(in: 0.10...0.38)
        let speed = (2 * 430 * (start.y - apex)).squareRoot()
        rockets.append(Rocket(
            position: start,
            velocity: CGVector(dx: .random(in: -30...30), dy: -speed),
            color: Self.palette.randomElement()!))
    }

    private func explode(_ rocket: Rocket) {
        let secondary = Bool.random() ? Self.palette.randomElement()! : rocket.color
        let ring = Double.random(in: 0...1) < 0.3
        let count = Int.random(in: 160...220)
        let maxSpeed = Double.random(in: 230...330)
        for n in 0..<count {
            let angle = Double.random(in: 0..<(2 * .pi))
            // a filled sphere looks even when radii follow the square root
            let speed = ring ? maxSpeed * .random(in: 0.92...1.0) : maxSpeed * Double.random(in: 0...1).squareRoot()
            sparks.append(Spark(
                position: rocket.position,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                life: .random(in: 1.8...3.0), radius: .random(in: 1.5...2.6),
                color: n % 3 == 0 ? secondary : rocket.color,
                twinkle: Double.random(in: 0...1) < 0.3, drag: 1.3, gravity: 55))
        }
        flashes.append(Flash(center: rocket.position, color: rocket.color))
        Haptics.light()
    }

    func draw(in context: inout GraphicsContext, glow: Bool) {
        if glow { context.blendMode = .plusLighter }

        for flash in flashes {
            let t = flash.age / 0.45
            let r = 14 + 110 * t
            let rect = CGRect(x: flash.center.x - r, y: flash.center.y - r, width: 2 * r, height: 2 * r)
            context.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.38 * (1 - t)), flash.color.opacity(0.18 * (1 - t)), .clear]),
                center: flash.center, startRadius: 0, endRadius: r))
        }

        for spark in rockets.map({ $0 }) {
            let head = CGRect(x: spark.position.x - 2.2, y: spark.position.y - 2.2, width: 4.4, height: 4.4)
            context.fill(Path(ellipseIn: head), with: .color(.white))
        }

        for spark in sparks {
            let progress = spark.age / spark.life
            var alpha = pow(1 - progress, 1.3)
            if spark.twinkle && progress > 0.35 { alpha *= 0.45 + 0.55 * abs(sin(spark.age * 28)) }
            guard alpha > 0.02 else { continue }

            if spark.trail.count > 1 {
                var tail = Path()
                tail.move(to: spark.trail[0])
                for point in spark.trail.dropFirst() { tail.addLine(to: point) }
                tail.addLine(to: spark.position)
                context.stroke(tail, with: .color(spark.color.opacity(alpha * 0.5)),
                               style: StrokeStyle(lineWidth: spark.radius * 0.9, lineCap: .round, lineJoin: .round))
            }
            let r = spark.radius * (1 - 0.35 * progress)
            if glow {
                let halo = CGRect(x: spark.position.x - r * 3, y: spark.position.y - r * 3, width: r * 6, height: r * 6)
                context.fill(Path(ellipseIn: halo), with: .color(spark.color.opacity(alpha * 0.22)))
            }
            let dot = CGRect(x: spark.position.x - r, y: spark.position.y - r, width: 2 * r, height: 2 * r)
            context.fill(Path(ellipseIn: dot), with: .color(spark.color.opacity(alpha)))
        }
    }
}
