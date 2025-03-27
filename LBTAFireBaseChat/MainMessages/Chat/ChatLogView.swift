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
        try? document.setData(messageData) { error in
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
}

struct ChatLogView: View {
    
    @ObservedObject var vm: ChatLogViewModel
    
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
    }
    
    static let emptyScrollToString = "Empty"
    @State private var shouldShowImagePicker = false
    
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
    
    let message: ChatMessage
    
    var body: some View {
        VStack {
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                if message.messageImageUrl != "" {
                    HStack{
                        Spacer()
                        HStack{
                            WebImage(url: URL(string: message.messageImageUrl ?? ""))
                                .resizable()
                                .frame(width: 180, height: 280)
                                .cornerRadius(20)
                        }
                        .padding(2)
                    }
                }
                HStack {
                    Spacer()
                    VStack(alignment: .trailing) {
                        if message.isForwarded == true {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .font(.system(size: 12))
                                Text("Forwarded")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.bottom, 2)
                        }
                        HStack {
                            Text(message.text)
                                .foregroundColor(.white)
                            if message.allowForwardMsg == "Y" {
                                Button {
                                    shouldShowForwardSheet.toggle()
                                } label: {
                                    Image(systemName: "arrowshape.turn.up.right")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.blue)
                    .cornerRadius(10)
                }.padding(2)
            } else {
                if message.messageImageUrl != "" {
                    HStack{
                        HStack{
                            WebImage(url: URL(string: message.messageImageUrl ?? ""))
                                .resizable()
                                .frame(width: 180, height: 280)
                                .cornerRadius(20)
                        }
                        .padding(2)
                        Spacer()
                    }
                }
                HStack {
                    VStack(alignment: .leading) {
                        if message.isForwarded == true {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .font(.system(size: 12))
                                Text("Forwarded")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black.opacity(0.8))
                            }
                            .padding(.bottom, 2)
                        }
                        HStack {
                            Text(message.text)
                                .foregroundColor(.black)
                            if message.allowForwardMsg == "Y" {
                                Button {
                                    shouldShowForwardSheet.toggle()
                                } label: {
                                    Image(systemName: "arrowshape.turn.up.right")
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(.white)
                    .cornerRadius(10)
                    
                    Spacer()
                }
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
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let toId = user.uid
        
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [
            FirebaseConstants.fromId: fromId,
            FirebaseConstants.toId: toId,
            FirebaseConstants.text: "Forwarded: \(message.text)",
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.allowForwardMsg: "Y",
            "messageImageUrl": message.messageImageUrl ?? "",
            "isForwarded": true,
            "originalSender": message.fromId
        ] as [String : Any]
        
        document.setData(messageData) { error in
            if let error = error {
                print("Failed to forward message: \(error)")
                return
            }
            
            // Save to recipient's messages
            let recipientDocument = FirebaseManager.shared.firestore
                .collection(FirebaseConstants.messages)
                .document(toId)
                .collection(fromId)
                .document()
            
            recipientDocument.setData(messageData) { error in
                if let error = error {
                    print("Failed to save forwarded message to recipient: \(error)")
                    return
                }
                
                // Update recent messages
                let recentMessageData = [
                    FirebaseConstants.timestamp: Timestamp(),
                    FirebaseConstants.text: "Forwarded: \(message.text)",
                    FirebaseConstants.fromId: fromId,
                    FirebaseConstants.toId: toId,
                    FirebaseConstants.profileImageUrl: FirebaseManager.shared.currentUser?.profileImageUrl ?? "",
                    FirebaseConstants.email: FirebaseManager.shared.currentUser?.email ?? "",
                    "messageImageUrl": message.messageImageUrl ?? ""
                ] as [String : Any]
                
                // Save to sender's recent messages
                FirebaseManager.shared.firestore
                    .collection(FirebaseConstants.recent_messages)
                    .document(fromId)
                    .collection(FirebaseConstants.messages)
                    .document(toId)
                    .setData(recentMessageData)
                
                // Save to recipient's recent messages
                FirebaseManager.shared.firestore
                    .collection(FirebaseConstants.recent_messages)
                    .document(toId)
                    .collection(FirebaseConstants.messages)
                    .document(fromId)
                    .setData(recentMessageData)
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
