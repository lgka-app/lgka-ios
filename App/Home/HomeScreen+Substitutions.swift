import SwiftUI
import LGKACore

extension HomeScreen {
    // ── Substitution cards ──────────────────────────────────────────────────

    @ViewBuilder var substitutionSection: some View {
        if model.subLoading {
            skeletonRow
            skeletonRow
        } else if model.subError {
            VStack(spacing: 12) {
                Image(systemName: "cloud.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.6))
                    .accessibilityHidden(true)
                Text(L.s("serverConnectionFailed")).font(.subheadline.weight(.semibold))
                Text(L.s("serverConnectionHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(L.s("tryAgain")) {
                    Haptics.light()
                    Task { await model.sync(only: [.substitutions]) }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            subCard(model.today, isToday: true).accessibilityIdentifier("home.plan.today")
            subCard(model.tomorrow, isToday: false).accessibilityIdentifier("home.plan.tomorrow")
        }
    }

    @ViewBuilder private func subCard(_ plan: DayPlan?, isToday: Bool) -> some View {
        if plan == nil && !model.subLoading && !model.subError {
            // per-card failure (home_screen per-day retry parity)
            Button {
                Haptics.medium()
                Task { await model.sync(only: [.substitutions]) }
            } label: {
                HStack(spacing: 14) {
                    IconSquare(systemName: "arrow.clockwise")
                    Text(L.s("errorLoading"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.s("errorLoading"))
            .accessibilityHint(L.s("a11y.retry"))
        } else {
            subCardContent(plan)
        }
    }

    @ViewBuilder private func subCardContent(_ plan: DayPlan?) -> some View {
        let canOpen = plan?.canDisplay ?? false
        let weekday = displayWeekday(plan?.meta.weekday)
        let title = canOpen ? weekday : L.s("noInfoYet")
        let subtitle: String? = {
            guard canOpen, let plan else { return nil }
            return "\(plan.meta.date) · " + String(localized: "substitutions.count \(plan.plan.entries.count)")
        }()
        Button {
            guard let plan, canOpen else { return }
            Haptics.medium()
            Task {
                // the mirrored PDF arrived with the sync; a missing file is fetched once
                do {
                    let file = try await model.pdfURL(for: plan.pdf)
                    pdfDestination = PdfDestination(fileUrl: DebugPdf.padded(file), title: weekday, targetPage: nil)
                } catch {
                    scheduleUnavailable = L.s("serverConnectionFailed")
                }
            }
        } label: {
            HStack(spacing: 14) {
                IconSquare(systemName: "calendar", alpha: canOpen ? 0.12 : 0.08)
                    .opacity(canOpen ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(canOpen ? .primary : Color.primary.opacity(0.35))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if canOpen {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .opacity(canOpen ? 1 : 0.6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.f("a11y.subPlan", title, subtitle ?? ""))
        .accessibilityAddTraits(canOpen ? .isButton : [])
    }

    private func displayWeekday(_ weekday: String?) -> String {
        guard let weekday, weekday != "weekend", !weekday.isEmpty else {
            return L.s("noInfoYet")
        }
        return L.weekday(weekday)
    }
}
