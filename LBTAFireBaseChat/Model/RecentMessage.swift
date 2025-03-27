//
//  RecentMessage.swift
//  ChatP2P
//
//  Created by Saar Bibla on 1/19/24.
//

import Foundation
import FirebaseFirestore

struct RecentMessage: Codable, Identifiable {
    var id: String?
    let text, email: String
    let fromId, toId: String
    let profileImageUrl: String
    let timestamp: Date
    let messageImageUrl: String?
    
    var username: String {
        email.components(separatedBy: "@").first ?? email
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case email
        case fromId
        case toId
        case profileImageUrl
        case timestamp
        case messageImageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        email = try container.decode(String.self, forKey: .email)
        fromId = try container.decode(String.self, forKey: .fromId)
        toId = try container.decode(String.self, forKey: .toId)
        profileImageUrl = try container.decode(String.self, forKey: .profileImageUrl)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        messageImageUrl = try container.decodeIfPresent(String.self, forKey: .messageImageUrl)
    }
}
