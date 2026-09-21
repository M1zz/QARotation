import SwiftData
import SwiftUI

struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ChecklistItem> { $0.isDefault }, sort: \ChecklistItem.order) private var items: [ChecklistItem]
    @State private var editing: ChecklistItem?
    @State private var adding = false

    var body: some View {
        List {
            ForEach(ChecklistCategory.allCases) { category in
                let rows = items.filter { $0.category == category }
                if !rows.isEmpty {
                    Section(category.label) {
                        ForEach(rows) { item in
                            Button(item.title) { editing = item }
                                .foregroundStyle(.primary)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(rows[index]) }
                            try? context.save()
                        }
                        .onMove { source, destination in
                            var reordered = rows
                            reordered.move(fromOffsets: source, toOffset: destination)
                            renumber(replacing: category, with: reordered)
                        }
                    }
                }
            }

            Section {
                Button("빠진 기본 항목 다시 넣기") { ChecklistSeeder.restoreMissing(context) }
            } footer: {
                Text("항목을 고쳐도 지난 QA 기록의 문구는 그대로 남아요.")
            }
        }
        .navigationTitle("기본 체크리스트")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button("추가", systemImage: "plus") { adding = true }
            }
        }
        .sheet(item: $editing) { item in
            ChecklistItemForm(item: item)
        }
        .sheet(isPresented: $adding) {
            ChecklistItemForm(item: nil)
        }
    }

    /// 분류 순서대로 펼쳐 0부터 다시 매긴다.
    private func renumber(replacing category: ChecklistCategory, with reordered: [ChecklistItem]) {
        var order = 0
        for current in ChecklistCategory.allCases {
            let rows = current == category ? reordered : items.filter { $0.category == current }
            for item in rows {
                item.order = order
                order += 1
            }
        }
        try? context.save()
    }
}

private struct ChecklistItemForm: View {
    let item: ChecklistItem?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ChecklistItem> { $0.isDefault }) private var items: [ChecklistItem]
    @State private var title = ""
    @State private var category: ChecklistCategory = .stability

    var body: some View {
        NavigationStack {
            Form {
                TextField("무엇을 확인하나요?", text: $title, axis: .vertical)
                Picker("분류", selection: $category) {
                    ForEach(ChecklistCategory.allCases) { Text($0.label).tag($0) }
                }
            }
            .navigationTitle(item == nil ? "항목 추가" : "항목 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let item {
                    title = item.title
                    category = item.category
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item {
            item.title = trimmed
            item.category = category
        } else {
            let order = (items.map(\.order).max() ?? -1) + 1
            context.insert(ChecklistItem(title: trimmed, category: category, order: order, isDefault: true))
        }
        try? context.save()
        dismiss()
    }
}
