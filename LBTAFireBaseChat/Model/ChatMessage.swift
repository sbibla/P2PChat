//
//  ChatMessage.swift
//  ChatP2P
//
//  Created by Saar Bibla on 1/21/24.
//

import Foundation
import FirebaseFirestoreSwift

//conforming to Identifiable ID so that each message is unique grabbing the uid from docID
struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let fromId, toId, text: String
    let timestamp: Date
    let allowForwardMsg: String
    let messageImageUrl: String?
    let isForwarded: Bool?
    let originalSender: String?
}
