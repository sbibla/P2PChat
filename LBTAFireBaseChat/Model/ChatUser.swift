//
//  ChatUser.swift
//  LBTAFireBaseChat
//
//  Created by Saar Bibla on 1/3/24.
//

import Foundation

struct ChatUser: Identifiable {
    
    var id: String { uid }
    let uid, email, profileImageUrl, creationDate, lastMessageDate, messageCanForwared: String
    var isOnline: Bool
    
    //initializer that takes all the dictionalry data
    init(data: [String: Any]){
        self.creationDate = data["creationDate"] as? String ?? ""
        self.uid = data["uid"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.lastMessageDate = data["lastMessageDate"] as? String ?? ""
        self.messageCanForwared = data["messageCanForwared"] as? String ?? ""
        self.isOnline = false
    }
}
