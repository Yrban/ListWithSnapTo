//
//  Message.swift
//  ListWithKeyboard
//
//  Created by Developer on 10/14/21.
//

import Foundation

// Data to demonstrate the app
struct Message: Identifiable, Hashable {
    let id = UUID()
    var messageText: String
    let date = Date()
    
    static func dataArray() -> [Message] {
        return Array(1...100).map( { Message(messageText: "message \($0)") } )
    }
}

