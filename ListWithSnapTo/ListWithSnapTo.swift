//
//  GenericListWithSnapTo.swift
//  ListWithKeyboard
//
//  Created by Developer on 1/14/22.
//

import SwiftUI
import Combine

struct ListWithSnapTo<Datum, Content>: View where Datum: Hashable, Datum: Identifiable, Content : View {
    
    public var data: Array<Datum>
    /// A function to create content on demand using the underlying data.
    public var content: (Array<Datum>.Element) -> Content
    
    @State var textfield: String = ""
    @State var visibleIndex: [Int:RowInfo] = [:]
    @State private var keyboardVisible = false
    @State private var readCells = true
    
    let scrollDetector: CurrentValueSubject<CGFloat, Never>
    let publisher: AnyPublisher<CGFloat, Never>
    
    public init(_ data: Array<Datum>, @ViewBuilder content: @escaping (Array<Datum>.Element) -> Content) {
        self.data = data
        self.content = content
        
        let detector = CurrentValueSubject<CGFloat, Never>(0)
        self.publisher = detector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        self.scrollDetector = detector
    }
    
    var body: some View {
        GeometryReader { outerProxy in
            ScrollViewReader { scroll in
                List {
                    ForEach(Array(zip(data.indices, data)), id: \.1) { (index, datum) in
                        GeometryReader { geometry in
                            content(datum)
                                .onChange(of: geometry.frame(in: .named("List"))) { innerRect in
                                    let rowInfo = RowInfo(index: index, datum: datum, rowOrigin: innerRect.origin.y)
                                    if isInView(rowInfo: rowInfo, innerRect: innerRect, isIn: outerProxy) {
                                        if readCells {
                                            visibleIndex[index] = rowInfo
                                        }
                                    } else {
                                        if readCells {
                                            visibleIndex.removeValue(forKey: index)
                                        }
                                    }
                                }
                        }
                    }
                    // The preferenceKey keeps track of the fact that the view is scrolling.
                    .background(GeometryReader {
                        Color.clear.preference(key: ViewOffsetKey.self,
                                               value: -$0.frame(in: .named("List")).origin.y)
                    })
                    .onPreferenceChange(ViewOffsetKey.self) { scrollDetector.send($0) }
                }
                .coordinateSpace(name: "List")
                .onAppear(perform: {
                    // Moves the view so that the cells on screen are recorded in visibleIndex.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let last = data.last {
                            scroll.scrollTo(last, anchor: .top)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let first = data.first {
                            scroll.scrollTo(first, anchor: .bottom)
                        }
                    }
                })
                // This keeps track of whether the keyboard is up or down by its actual appearance on the screen.
                // The change in keyboardVisible allows the reset for the last cell to be set just above the keyboard.
                // readCells is a flag that prevents the scrolling from changing the last view.
                .onReceive(Publishers.keyboardHeight) { keyboardHeight in
                    if keyboardHeight > 0 {
                        keyboardVisible = true
                        readCells = false
                    } else {
                        // This allows time for the keyboard to actually disappear from the screen before setting keyboardVisible
                        // true. Timing is everything. keyboardHeight > 0 is false immediately. If it is not fully down, it
                        // interferes with the scrollTo.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        keyboardVisible = false
                        }
                        // This allows time for the scrollTo to settle in.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            readCells = true
                        }
                    }
                }
                // This keeps track of whether the view is scrolling. If it is, it waits a bit,
                // and then sets the last visible message to the very bottom to snap it into place.
                // Remove this if you don't want this behavior.
                .onReceive(publisher) { _ in
                    if !keyboardVisible {
                        guard let lastVisibleIndex = visibleIndex.keys.max(),
                              let lastVisibleMessage = visibleIndex[lastVisibleIndex] else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            readCells = false
                            scroll.scrollTo(lastVisibleMessage.datum, anchor: .bottom)
                            // if the keyboard is visible, the keyboardHeight publisher handles the scrollTo.
                            if !keyboardVisible {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    readCells = true
                                }
                            }
                        }
                    }
                }
                .onChange(of: keyboardVisible) { _ in
                    guard let lastVisibleIndex = visibleIndex.keys.max(),
                          let lastVisibleMessage = visibleIndex[lastVisibleIndex] else { return }
                    if keyboardVisible {
                        // Waits until the keyboard is up. 0.25 seconds seems to be the best wait time.
                        // Too early, and the last cell hides behind the keyboard.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            // this helps make it look deliberate and finished
                            withAnimation(.easeOut(duration: 0.5)) {
                                scroll.scrollTo(lastVisibleMessage.datum, anchor: .bottom)
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.5)) {
                            scroll.scrollTo(lastVisibleMessage.datum, anchor: .bottom)
                        }
                    }
                }
                TextField("Write here...", text: $textfield)
                    .padding()
            }
        }
    }
    
    struct RowInfo {
        let index: Int
        let datum: Datum
        let rowOrigin: CGFloat
    }

    
    private func isInView(rowInfo: RowInfo, innerRect:CGRect, isIn outerProxy:GeometryProxy) -> Bool {
        let innerOrigin = innerRect.origin.y
        // This is an estimated row height based on the height of the contents plus a basic amount for the padding, etc. of the List
        // Have not been able to determine the actual height of the row. This may need to be adjusted.
        let rowHeight: CGFloat
        if let nextRow = visibleIndex[rowInfo.index + 1] {
            // This determines the center of the separator between the rows
            rowHeight = Double(Int((nextRow.rowOrigin - rowInfo.rowOrigin) / 2.0))
        } else {
            // Through experimentation, have found the space between rows defaults to 44 plus a little unless
            //  changed explicitly. The center between the rows is thus 22.
            rowHeight = innerRect.height + 22
        }
        let listOrigin = outerProxy.frame(in: .global).origin.y
        let listHeight = outerProxy.size.height
        if innerOrigin + rowHeight < listOrigin + listHeight && innerOrigin > listOrigin {
            return true
        }
        return false
    }
    
}

fileprivate struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

struct GenericListWithSnapTo_Previews: PreviewProvider {
    @State static var messages: [Message] = Message.dataArray()
    static var previews: some View {
        ListWithSnapTo(messages) { message in
            Text(message.messageText)
        }
    }
}
