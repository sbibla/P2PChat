//
//  ChatMessage.swift
//  ChatP2P
//
//  Created by Saar Bibla on 1/21/24.
//

import Foundation
import FirebaseFirestore

//conforming to Identifiable ID so that each message is unique grabbing the uid from docID
struct ChatMessage: Codable, Identifiable {
    var id: String?
    let fromId, toId, text: String
    let timestamp: Date
    let allowForwardMsg: String
    let messageImageUrl: String?
    let isForwarded: Bool?
    let originalSender: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromId
        case toId
        case text
        case timestamp
        case allowForwardMsg
        case messageImageUrl
        case isForwarded
        case originalSender
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        fromId = try container.decode(String.self, forKey: .fromId)
        toId = try container.decode(String.self, forKey: .toId)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        allowForwardMsg = try container.decode(String.self, forKey: .allowForwardMsg)
        messageImageUrl = try container.decodeIfPresent(String.self, forKey: .messageImageUrl)
        isForwarded = try container.decodeIfPresent(Bool.self, forKey: .isForwarded)
        originalSender = try container.decodeIfPresent(String.self, forKey: .originalSender)
    }
}
