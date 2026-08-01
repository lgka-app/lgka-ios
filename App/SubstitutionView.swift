import SwiftUI

struct SubstitutionView: View {
    @State private var day: Day = .today
    enum Day: String, CaseIterable, Identifiable {
        case today = "Heute", tomorrow = "Morgen"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            LoadableView(load: {
                async let today = SchoolAPI.substitutionPlan(today: true)
                async let tomorrow = SchoolAPI.substitutionPlan(today: false)
                return try await [Day.today: today, .tomorrow: tomorrow]
            }) { (plans: [Day: SchoolAPI.SubPlan]) in
                planList(plans[day])
            }
            .navigationTitle("Vertretungsplan")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Tag", selection: $day) {
                        ForEach(Day.allCases) { d in Text(d.rawValue).tag(d) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }

    @ViewBuilder
    private func planList(_ plan: SchoolAPI.SubPlan?) -> some View {
        if let plan, !plan.isEmpty {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(plan.weekday ?? ""), \(plan.planDate ?? "")")
                                .font(.headline)
                            if let generated = plan.generatedAt {
                                Text("Stand: \(generated)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.tint)
                    }
                }

                if !plan.announcements.isEmpty {
                    Section("Ankündigungen") {
                        ForEach(plan.announcements, id: \.self) { a in
                            Label(a, systemImage: "megaphone.fill")
                                .font(.subheadline)
                        }
                    }
                }

                if !plan.absentTeachers.isEmpty || !plan.absentClasses.isEmpty {
                    Section("Abwesend") {
                        if !plan.absentTeachers.isEmpty {
                            LabeledContent("Lehrer",
                                value: plan.absentTeachers.joined(separator: ", "))
                        }
                        if !plan.absentClasses.isEmpty {
                            LabeledContent("Klassen",
                                value: plan.absentClasses.joined(separator: ", "))
                        }
                    }
                }

                Section(plan.entries.isEmpty ? "" : "Vertretungen") {
                    if plan.entries.isEmpty {
                        ContentUnavailableView("Keine Vertretungen",
                            systemImage: "checkmark.circle",
                            description: Text("Für diesen Tag gibt es keine Einträge."))
                    } else {
                        ForEach(plan.entries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView("Kein Plan verfügbar",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Am Wochenende und in den Ferien gibt es keinen Vertretungsplan."))
        }
    }
}

struct EntryRow: View {
    let entry: SchoolAPI.SubPlan.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.classes.joined(separator: ", "))
                    .font(.headline)
                if let period = entry.period {
                    Text("Std. \(period)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let type = entry.type {
                    Text(type)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor(type).opacity(0.18), in: Capsule())
                        .foregroundStyle(badgeColor(type))
                }
            }
            HStack(spacing: 14) {
                if let subject = entry.subject ?? entry.originalSubject {
                    Label(subject, systemImage: "book.closed")
                }
                if let teacher = entry.substitute ?? entry.originalTeacher {
                    Label(teacher, systemImage: "person")
                }
                if let room = entry.room ?? entry.originalRoom {
                    Label(room, systemImage: "door.left.hand.open")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let note = entry.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
    }

    private func badgeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case let t where t.contains("entfall"): return .red
        case let t where t.contains("veranst"): return .purple
        case let t where t.contains("raum"): return .orange
        default: return .blue
        }
    }
}
