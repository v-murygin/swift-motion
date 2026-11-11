import SwiftUI

struct InboxView: View {
    @State private var query = ""
    @State private var messages: [Message] = Message.samples
    @State private var showComposer = false
    @State private var selected: Message.ID?
    @State private var pulse = false

    var filtered: [Message] {
        query.isEmpty ? messages : messages.filter { $0.subject.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { message in
                MessageRow(message: message, isSelected: selected == message.id)
                    .onTapGesture { selected = message.id }
            }
            .animation(.default)
            .searchable(text: $query)
            .onChange(of: query) {
                withAnimation(.linear(duration: 1.0)) { messages.sort { $0.date > $1.date } }
            }
            .toolbar {
                Button { showComposer = true } label: {
                    Image(systemName: "square.and.pencil")
                        .scaleEffect(pulse ? 1.15 : 1)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true }
                        }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .overlay(alignment: .bottom) {
                if showComposer {
                    ComposerPanel(isPresented: $showComposer)
                        .transition(.scale(scale: 0))
                }
            }
            .animation(.easeIn(duration: 0.6), value: showComposer)
        }
    }
}

struct MessageRow: View {
    let message: Message
    let isSelected: Bool
    var body: some View {
        VStack(alignment: .leading) {
            Text(message.subject).font(.headline)
            Text(message.preview).foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .shadow(radius: isSelected ? 12 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.3), value: isSelected)
    }
}

struct ComposerPanel: View {
    @Binding var isPresented: Bool
    var body: some View {
        VStack { Text("New message"); Button("Cancel") { isPresented = false } }
            .frame(maxWidth: .infinity).frame(height: 300)
            .background(.regularMaterial)
    }
}

struct Message: Identifiable {
    let id = UUID(); let subject: String; let preview: String; let date: Date
    static let samples: [Message] = (0..<30).map { Message(subject: "Subject \($0)", preview: "Preview text \($0)", date: .now.addingTimeInterval(Double(-$0) * 3600)) }
}
