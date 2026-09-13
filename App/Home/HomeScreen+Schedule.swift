import SwiftUI
import LGKACore

extension HomeScreen {
    // ── Schedule card ───────────────────────────────────────────────────────

    @ViewBuilder var scheduleSection: some View {
        if model.scheduleLoading {
            skeletonRow
        } else if model.scheduleError {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
                Text(L.s("serverConnectionFailed"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                retryButton { await model.sync(only: [.schedules]) }
            }
            .padding(.vertical, 8)
        } else if preferredGroup.isEmpty {
            // also when no item names a known Halbjahr: a class card would open nothing
            HStack(spacing: 12) {
                Image(systemName: "clock").foregroundStyle(.secondary.opacity(0.4))
                    .accessibilityHidden(true)
                Text(L.s("noSchedulesAvailable"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        } else if prefs.selectedScheduleClass.isEmpty {
            homeCard(icon: "graduationcap",
                     title: L.s("scheduleNoClassTitle"),
                     subtitle: L.s("scheduleNoClassSub")) {
                Haptics.light()
                classInput = ""
                showClassDialog = true
            }
        } else {
            let cls = prefs.selectedScheduleClass
            let half = preferredGroup.first?.halbjahr == "1. Halbjahr"
                ? L.s("firstSemester") : L.s("secondSemester")
            homeCard(icon: "tablecells",
                     title: L.className(cls),
                     subtitle: half) {
                openSchedule(for: cls)
            }
            .accessibilityIdentifier("home.schedule")
            .contextMenu {
                Button(L.s("setClassTitle"), systemImage: "pencil") {
                    Haptics.light()
                    classInput = cls
                    showClassDialog = true
                }
            }
        }
    }

    private func homeCard(icon: String, title: String, subtitle: String,
                          action: @escaping () -> Void) -> some View {
        Button { Haptics.medium(); action() } label: {
            HStack(spacing: 14) {
                IconSquare(systemName: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    private var preferredGroup: [ScheduleItem] { model.preferredGroup }

    private func openSchedule(for cls: String) {
        // the PDF whose discovered grades contain the class (5-10, J11, J12, a future J13, …)
        guard let target = HomeScreen.schedule(for: cls, in: preferredGroup) else { return }
        let half = target.halbjahr == "1. Halbjahr"
            ? L.s("firstSemester") : L.s("secondSemester")
        guard target.available, let pdf = target.pdf else {
            // home_screen SnackBar parity: the school has not published this PDF yet
            scheduleUnavailable = L.f("scheduleNotAvailable", half)
            return
        }

        // opens straight away like the substitution cards: the PDF is already on disk
        Task {
            do {
                let file = try await model.pdfURL(for: pdf)
                pdfDestination = PdfDestination(
                    fileUrl: file,
                    title: L.className(cls), // pdf_viewer header: class only
                    targetPage: target.pageIndex(forClass: cls),
                    schedule: target,
                    classIndex: target.classIndex)
            } catch {
                scheduleUnavailable = L.f("scheduleNotAvailable", half)
            }
        }
    }

    /// The schedule PDF for a class: by discovered grades first, then by the
    /// gradeLevel label, then the first available PDF.
    static func schedule(for cls: String, in group: [ScheduleItem]) -> ScheduleItem? {
        if let exact = group.first(where: { $0.covers(cls) }) { return exact }
        let jahrgang = (ScheduleGrades.gradeOf(cls) ?? 0) >= 11
        return group.first(where: { jahrgang ? $0.grades.contains(where: { $0 >= 11 }) : $0.grades.contains(where: { $0 <= 10 }) })
            ?? group.first(where: { jahrgang ? $0.gradeLevel == "J11/J12" : $0.gradeLevel == "Klassen 5-10" })
            ?? group.first
    }
}
