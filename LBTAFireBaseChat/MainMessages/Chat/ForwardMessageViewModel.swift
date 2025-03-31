import SwiftUI
import Firebase

class ForwardMessageViewModel: ObservableObject {
    @Published var users = [ChatUser]()
    @Published var errorMessage = ""
    
    init() {
        fetchAllUsers()
    }
    
    private func fetchAllUsers() {
        FirebaseManager.shared.firestore.collection("users")
            .getDocuments { documentsSnapshot, error in
                if let error = error {
                    print("Failed to fetch users: \(error)")
                    self.errorMessage = "Failed to fetch users: \(error)"
                    return
                }
                
                documentsSnapshot?.documents.forEach({ snapshot in
                    let data = snapshot.data()
                    let user = ChatUser(data: data)
                    // Don't show current user in the list
                    if user.uid != FirebaseManager.shared.auth.currentUser?.uid {
                        self.users.append(user)
                    }
                })
            }
    }
} 