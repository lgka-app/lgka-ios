import SwiftUI
import PDFKit

struct ScheduleView: View {
    var body: some View {
        NavigationStack {
            LoadableView(load: { try await SchoolAPI.schedules() }) { schedules in
                List {
                    ForEach(["2. Halbjahr", "1. Halbjahr"], id: \.self) { half in
                        let items = schedules.filter { $0.halbjahr == half }
                        if !items.isEmpty {
                            Section(half) {
                                ForEach(items) { schedule in
                                    NavigationLink(value: schedule.fullUrl) {
                                        Label(schedule.gradeLevel,
                                              systemImage: schedule.gradeLevel.contains("J11")
                                                ? "graduationcap" : "studentdesk")
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: String.self) { url in
                    if let schedule = schedules.first(where: { $0.fullUrl == url }) {
                        SchedulePdfScreen(schedule: schedule)
                    }
                }
            }
            .navigationTitle("Stundenplan")
        }
    }
}

struct SchedulePdfScreen: View {
    let schedule: SchoolAPI.Schedule
    @State private var selectedClass: String?

    var body: some View {
        LoadableView(load: { try await SchoolAPI.schedulePdf(schedule) }) { (url, index) in
            PdfClassView(fileUrl: url, classIndex: index, selectedClass: $selectedClass)
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom) {
                    if !index.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            GlassEffectContainer {
                                HStack(spacing: 8) {
                                    ForEach(index.keys.sorted(by: classSort), id: \.self) { name in
                                        Button(name.uppercased()) {
                                            selectedClass = name
                                        }
                                        .buttonStyle(.glass)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
        }
        .navigationTitle("\(schedule.gradeLevel) · \(schedule.halbjahr)")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 5a..10e in grade order (lexicographic would put 10a before 5a).
    private func classSort(_ a: String, _ b: String) -> Bool {
        func key(_ s: String) -> (Int, String) {
            let digits = s.prefix { $0.isNumber }
            return (Int(digits) ?? 99, String(s.dropFirst(digits.count)))
        }
        return key(a) < key(b)
    }
}

struct PdfClassView: UIViewRepresentable {
    let fileUrl: URL
    let classIndex: [String: Int]
    @Binding var selectedClass: String?

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: fileUrl)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard let name = selectedClass,
              let display = classIndex[name],
              let doc = view.document else { return }
        // index stores pageIndex + 2 (verified contract); PDFKit is 0-based
        let pageIndex = max(0, min(doc.pageCount - 1, display - 2))
        if let page = doc.page(at: pageIndex) {
            view.go(to: page)
        }
    }
}
