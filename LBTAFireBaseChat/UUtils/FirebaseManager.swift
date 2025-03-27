//
//  FirebaseManager.swift
//  LBTAFireBaseChat
//
//  Created by Saar Bibla on 1/2/24.
//  FireBase singleton

import Foundation
import FirebaseFirestore
import Firebase
import FirebaseStorage
import FirebaseAuth

struct FirebaseConstants {
    static let uid = "uid"
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let timestamp = "timestamp"
    static let allowForwardMsg = "allowForwardMsg"
    static let profileImageUrl = "profileImageUrl"
    static let email = "email"
    static let recent_messages = "recent_messages"
    static let messages = "messages"
    static let users = "users"

}

class FirebaseManager: NSObject {
    
    let auth: Auth
    let storage: Storage
    let firestore: Firestore
    
    var currentUser: ChatUser?
    static let shared = FirebaseManager()
    
    override init() {
        FirebaseApp.configure()
        
        self.auth = Auth.auth()
        self.storage = Storage.storage()
        self.firestore = Firestore.firestore() //init firestore
        
        super.init()
    }
    
}//singleton

