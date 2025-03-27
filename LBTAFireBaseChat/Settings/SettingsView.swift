import SwiftUI
import Firebase

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var allowMessageForwarding = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Message Settings")) {
                    Toggle("Allow Message Forwarding", isOn: $allowMessageForwarding)
                        .onChange(of: allowMessageForwarding) { newValue in
                            updateForwardingPermission(allow: newValue)
                        }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .alert("Settings Update", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadUserSettings()
            }
        }
    }
    
    private func loadUserSettings() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                alertMessage = "Failed to load settings: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            if let data = snapshot?.data() {
                let messageCanForward = data["messageCanForwared"] as? String ?? "N"
                allowMessageForwarding = messageCanForward == "Y"
            }
        }
    }
    
    private func updateForwardingPermission(allow: Bool) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        let value = allow ? "Y" : "N"
        FirebaseManager.shared.firestore.collection("users").document(uid).updateData([
            "messageCanForwared": value
        ]) { error in
            if let error = error {
                alertMessage = "Failed to update settings: \(error.localizedDescription)"
                showAlert = true
                return
            }
            alertMessage = "Settings updated successfully"
            showAlert = true
        }
    }
}

#Preview {
    SettingsView()
} 