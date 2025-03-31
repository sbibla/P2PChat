//
//  ChatLogView.swift
//  BChainChat
//
//  Created by Saar Bibla on 1/16/24.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI
//move to constFile FirebaseConstants


struct ChatLogViewConst {
    static let send = "Send"
    static let securedMessage = "Secured message"
}


class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    //    @Published var messageCanForwared = "N"
    
    @Published var messageImage: UIImage?
    var chatUser: ChatUser?
    var messageImageUrl = ""
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        
        fetchMessages()
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        firestoreListener?.remove()
        chatMessages.removeAll()
        firestoreListener = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        do {
                            let cm = try change.document.data(as: ChatMessage.self)
                            self.chatMessages.append(cm)
                            //                                print("Appending chatMessage in ChatLogView: \(Date())")
                            
                        } catch {
                            print("Failed to decode message: \(error)")
                        }
                    }
                })
                
                DispatchQueue.main.async {
                    self.count += 1
                }
            }
    }
    func saveImageToChatStorage() {
        //        let filename = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid
        else {return }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.messageImage?.jpegData(compressionQuality: 0.5) else {return }
        
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                self.errorMessage = "Failed to push image to Storage: \(err)"
                print(self.errorMessage)
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    self.errorMessage = "Failed to retrieve downloadURL: \(err)"
                    return
                }
                print("Successfully stored message image with url: \(url?.absoluteString ?? "")")
                self.messageImageUrl = url?.absoluteString ?? ""
                print("saveImageTCS: MessageURL \(self.messageImageUrl)")
                //store user information
                //unwrapping first since optional
//                guard let url = url else {return}
//                self.storeMessageImageUrltoMessage(ImageUrl: url)

            }
        }
    }
    func storeMessageImageUrltoMessage(ImageUrl: URL){
        
    }
    func handleSend() {
        
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return}
        guard let toId = chatUser?.uid else {return}
        guard let messagePermissions = chatUser?.messageCanForwared else {return}
        
        //        If message contains Image, save Image to Firestore, and gather URL

        

        
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .document()
        
        //May suffer from a race condition, where URL isn't
        self.saveImageToChatStorage()
        
        //saving the message to firestore
        print("sending: \(chatText) from:\(fromId) to:\(toId) canForward:\(messagePermissions) Image:\(messageImageUrl)")
        
        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text: self.chatText, FirebaseConstants.timestamp: Timestamp(), FirebaseConstants.allowForwardMsg: messagePermissions, "messageImageUrl": messageImageUrl] as [String : Any]
        document.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message to sender firestore \(error)"
                return
            }
            print("Successfully saved current user sending message")
            
            self.persistRecentmessage()
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(toId)
            .collection(fromId)
            .document()
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message to recepient firestore \(error)"
                print(self.errorMessage)
                return
            }
            print("Recepient saved message as well")
        }
    }
    private func persistRecentmessage() {
        
        guard let chatUser = chatUser else {return}
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        guard let toId = self.chatUser?.uid else { return }
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recent_messages)
            .document(uid)
            .collection(FirebaseConstants.messages)
            .document(toId)
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            FirebaseConstants.email: chatUser.email,
            "messageImageUrl": messageImageUrl ] as [String: Any]
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print(self.errorMessage)
                return
            }
            
            //save another dictionary for the repcepient of this message
            guard let currentUser = FirebaseManager.shared.currentUser else { return }
            let recipientRecentMessageDictionary = [
                FirebaseConstants.timestamp: Timestamp(),
                FirebaseConstants.text: self.chatText,
                FirebaseConstants.fromId: uid,
                FirebaseConstants.toId: toId,
                FirebaseConstants.profileImageUrl: currentUser.profileImageUrl,
                FirebaseConstants.email: currentUser.email,
                "messageImageUrl": self.messageImageUrl ] as [String: Any]
            
            FirebaseManager.shared.firestore
                .collection(FirebaseConstants.recent_messages)
                .document(toId)
                .collection(FirebaseConstants.messages)
                .document(currentUser.uid)
                .setData(recipientRecentMessageDictionary) { error in
                    if let error = error {
                        self.errorMessage = "Failed to save recipient recent message \(error)"
                        print(self.errorMessage)
                        return
                    }
                }
        }
    }
    
    @Published var count = 0
    
    func clearAllFirestoreData() {
        let db = FirebaseManager.shared.firestore
        
        // Clear messages collection
        db.collection(FirebaseConstants.messages).getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error getting messages: \(error)")
                return
            }
            
            let batch = db.batch()
            for document in snapshot!.documents {
                // Delete all subcollections
                document.reference.getCollections { collections, error in
                    if let error = error {
                        print("Error getting collections: \(error)")
                        return
                    }
                    
                    for collection in collections ?? [] {
                        collection.getDocuments { documents, error in
                            if let error = error {
                                print("Error getting documents: \(error)")
                                return
                            }
                            
                            for doc in documents ?? [] {
                                doc.reference.delete { error in
                                    if let error = error {
                                        print("Error deleting document: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }
                
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("Error committing batch: \(error)")
                } else {
                    print("Successfully cleared messages collection")
                }
            }
        }
        
        // Clear recent messages collection
        db.collection(FirebaseConstants.recent_messages).getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error getting recent messages: \(error)")
                return
            }
            
            let batch = db.batch()
            for document in snapshot!.documents {
                // Delete all subcollections
                document.reference.getCollections { collections, error in
                    if let error = error {
                        print("Error getting collections: \(error)")
                        return
                    }
                    
                    for collection in collections ?? [] {
                        collection.getDocuments { documents, error in
                            if let error = error {
                                print("Error getting documents: \(error)")
                                return
                            }
                            
                            for doc in documents ?? [] {
                                doc.reference.delete { error in
                                    if let error = error {
                                        print("Error deleting document: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }
                
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("Error committing batch: \(error)")
                } else {
                    print("Successfully cleared recent messages collection")
                }
            }
        }
        
        // Clear users collection
        db.collection("users").getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error getting users: \(error)")
                return
            }
            
            let batch = db.batch()
            for document in snapshot!.documents {
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("Error committing batch: \(error)")
                } else {
                    print("Successfully cleared users collection")
                }
            }
        }
    }
}

struct ChatLogView: View {
    
    @ObservedObject var vm: ChatLogViewModel
    @State private var shouldShowImagePicker = false
    @State private var shouldShowForwardSheet = false
    @State private var selectedMessage: ChatMessage?
    @State private var forwardViewModel = ForwardMessageViewModel()
    @State private var showingClearDataAlert = false
    
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.firestoreListener?.remove()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingClearDataAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                vm.clearAllFirestoreData()
            }
        } message: {
            Text("This will permanently delete all messages and user data from Firestore. This action cannot be undone.")
        }
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View {
        VStack {
            if #available(iOS 15.0, *) {
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack {
                            ForEach(vm.chatMessages) { message in
                                MessageView(message: message)
                            }
                            
                            HStack { Spacer() }
                                .id(Self.emptyScrollToString)
                        }
                        .onReceive(vm.$count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.init(white: 0.95, alpha: 1)))
                .safeAreaInset(edge: .bottom) {
                    chatBottomBar
                        .background(Color(.systemBackground).ignoresSafeArea())
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Button {
                shouldShowImagePicker.toggle()
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 24))
                    .foregroundColor(Color(.darkGray))
            }
            .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil, content: {
                ImagePicker(image: $vm.messageImage)
            })
            ZStack {
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
            Button {
                vm.handleSend()
            } label: {
                Text(ChatLogViewConst.send)
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(20)
            .disabled(vm.chatText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical,4)
    }
}

//Checking if the message is from current user to decide colour
struct MessageView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var shouldShowForwardSheet = false
    @ObservedObject var forwardViewModel = CreateNewMessageViewModel()
    @State private var originalSenderEmail: String = ""
    @State private var selectedMessage: ChatMessage?
    @State private var errorMessage = ""
    
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading) {
                if message.isForwarded ?? false {
                    Text("Forwarded: \(message.originalSenderEmail ?? "")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack(alignment: .bottom) {
                    if !message.isFromCurrentUser {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    
                    if message.isFromCurrentUser && message.allowForwardMsg == "Y" {
                        Button {
                            selectedMessage = message
                            shouldShowForwardSheet = true
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                    }
                    
                    if message.isFromCurrentUser {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                }
                .padding(10)
                .background(message.isFromCurrentUser ? Color.blue : Color(.systemGray5))
                .cornerRadius(20)
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onAppear {
            if message.isForwarded == true, let originalSenderId = message.originalSender {
                fetchOriginalSenderEmail(senderId: originalSenderId)
            }
        }
        .sheet(isPresented: $shouldShowForwardSheet) {
            NavigationView {
                ScrollView {
                    ForEach(forwardViewModel.users) { user in
                        Button {
                            forwardMessage(to: user)
                            shouldShowForwardSheet = false
                        } label: {
                            HStack(spacing: 16) {
                                WebImage(url: URL(string: user.profileImageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .cornerRadius(50)
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
                }
                .navigationTitle("Forward Message")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            shouldShowForwardSheet = false
                        } label: {
                            Text("Cancel")
                        }
                    }
                }
            }
        }
    }
    
    private func fetchOriginalSenderEmail(senderId: String) {
        FirebaseManager.shared.firestore.collection("users").document(senderId).getDocument { snapshot, error in
            if let error = error {
                print("Failed to fetch original sender email: \(error)")
                return
            }
            
            if let data = snapshot?.data(),
               let email = data[FirebaseConstants.email] as? String {
                DispatchQueue.main.async {
                    self.originalSenderEmail = email
                }
            }
        }
    }
    
    private func forwardMessage(to user: ChatUser) {
        guard let selectedMessage = selectedMessage else { return }
        
        let messageData: [String: Any] = [
            FirebaseConstants.text: "Forwarded: \(selectedMessage.text)",
            FirebaseConstants.fromId: FirebaseManager.shared.auth.currentUser?.uid ?? "",
            FirebaseConstants.toId: user.uid,
            FirebaseConstants.timestamp: Timestamp(),
            "isForwarded": true,
            "originalSender": selectedMessage.fromId,
            "originalSenderEmail": selectedMessage.fromId == FirebaseManager.shared.auth.currentUser?.uid ? FirebaseManager.shared.currentUser?.email : selectedMessage.originalSenderEmail,
            "messageCanForwared": "Y"
        ]
        
        // Save to sender's messages
        let senderMessageDocument = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(FirebaseManager.shared.auth.currentUser?.uid ?? "")
            .collection(user.uid)
            .document()
        
        senderMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message to sender firestore \(error)"
                print(self.errorMessage)
                return
            }
            print("Sender saved message")
        }
        
        // Save to recipient's messages
        let recipientMessageDocument = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(user.uid)
            .collection(FirebaseManager.shared.auth.currentUser?.uid ?? "")
            .document()
        
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message to recepient firestore \(error)"
                print(self.errorMessage)
                return
            }
            print("Recepient saved message as well")
        }
        
        // Update recent messages
        let recentMessageData: [String: Any] = [
            FirebaseConstants.text: "Forwarded: \(selectedMessage.text)",
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.email: user.email,
            FirebaseConstants.profileImageUrl: user.profileImageUrl,
            FirebaseConstants.fromId: FirebaseManager.shared.auth.currentUser?.uid ?? "",
            FirebaseConstants.toId: user.uid
        ]
        
        // Update sender's recent messages
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recent_messages)
            .document(FirebaseManager.shared.auth.currentUser?.uid ?? "")
            .collection(FirebaseConstants.messages)
            .document(user.uid)
            .setData(recentMessageData) { error in
                if let error = error {
                    print(error)
                    return
                }
            }
        
        // Update recipient's recent messages
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recent_messages)
            .document(user.uid)
            .collection(FirebaseConstants.messages)
            .document(FirebaseManager.shared.auth.currentUser?.uid ?? "")
            .setData(recentMessageData) { error in
                if let error = error {
                    print(error)
                    return
                }
            }
    }
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Secured message")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}
#Preview {
    //    NavigationView {
    //        ChatLogView(chatUser: .init(data: ["uid": "NrTrCkcrzkaFJ6EHgG36tBhPzby1", "email" : "ac@gmail.com"]))
    //    }
    MainMessagesView()
}
