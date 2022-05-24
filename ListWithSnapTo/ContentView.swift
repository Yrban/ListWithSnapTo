//
//  ContentView.swift
//  ListWithSnapTo
//
//  Created by Developer on 5/22/22.
//

import SwiftUI

struct ContentView: View {
    
    @State var messages: [Message] = Message.dataArray()

    var body: some View {
        NavigationView {
            VStack {
                Text("This is some text to take up a lot of space to mess with the list below.")
                    .padding(50)
                ListWithSnapTo(messages) { message in
                    Text(message.messageText)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
