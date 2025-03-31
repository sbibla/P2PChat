import SwiftUI
import Firebase

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var shouldShowLogOutOptions = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(role: .destructive) {
                        shouldShowLogOutOptions.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
            }
            .actionSheet(isPresented: $shouldShowLogOutOptions) {
                .init(title: Text("Sign Out"), message: Text("Are you sure you want to sign out?"), buttons: [
                    .destructive(Text("Sign Out"), action: {
                        do {
                            try FirebaseManager.shared.auth.signOut()
                            presentationMode.wrappedValue.dismiss()
                        } catch {
                            print("Error signing out: \(error)")
                        }
                    }),
                    .cancel()
                ])
            }
        }
    }
}

#Preview {
    SettingsView()
} 