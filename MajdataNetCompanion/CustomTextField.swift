import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .autocapitalization(.none)
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color.blue : Color.gray.opacity(0.3),
                    lineWidth: isFocused ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
        )
        .focused($isFocused)
        .frame(maxWidth: 400)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

#Preview {
    CustomTextField(placeholder: "Enter Chart ID or URL", text: .constant(""))
        .padding()
} 