//
//  CreateNewMessageView.swift
//  LBTAFireBaseChat
//
//  Created by Saar Bibla on 1/4/24.
//

import SwiftUI
import SDWebImageSwiftUI

class CreateNewMessageViewModel: ObservableObject {
    
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
                    //don't show current user
                    let user = ChatUser(data: data)
                    if user.uid != FirebaseManager.shared.auth.currentUser?.uid {
                        self.users.append(.init(data: data))
                    }

                })
            }
         
    }
}

struct CreateNewMessageView: View {
    
    //callback to know which user was selected
    let didSelectNewUser: (ChatUser) -> ()
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var vm = CreateNewMessageViewModel()
    var body: some View {
        
        NavigationView {
            ScrollView {
                Text(vm.errorMessage)
                ForEach(vm.users) { user in
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        didSelectNewUser(user)
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped() //clip the edges
                                .cornerRadius(50)
                            //Drawing a border around the image
                                .overlay(RoundedRectangle(cornerRadius: 50)
                                    .stroke(Color(.label), lineWidth: 2))
                                
                            Text(user.email)
                                .foregroundColor(Color(.label))
                            Spacer()
                        }.padding(.horizontal)
                    }
                    Divider()
                        .padding(.vertical, 8)
                    }
            }.navigationTitle("New Message")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Cancel")
                        }
                    }
                }
        }
    }
}

#Preview {
//    CreateNewMessageView()
    MainMessagesView()
}
