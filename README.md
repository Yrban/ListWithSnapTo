# ListWithSnapTo
Entry for SwiftUI Series: Workarounds

(https://github.com/Yrban/ListWithSnapTo/blob/main/ListWithSnapTo.gif)

This workaround started from a Stack Overflow question: [How do I get the ScrollView to keep its position when the keyboard appears with iOS 15/Xcode 13?
](https://stackoverflow.com/questions/69500656/how-do-i-get-the-scrollview-to-keep-its-position-when-the-keyboard-appears-with) The issue stems from an area where SwiftUI is not fully mature. When the keyboard appears in UIKit with a Scroll View, it will keep the position of the last element in the view above the keyboard. Lists in SwiftUI won't do that. There are two options: use a UIViewRepresentable or this workaround. The original poster wanted an answer that was essentially SwiftUI. I say essentially, as I had to dive into UIKit a bit to come up with some extensions to determine whether the keyboard was on screen or not.

The first issue I ran into is that `.onAppear()` does not mean "on screen". It really is more akin to `viewWillAppear()`. What I needed was a `viewDidAppear` and a `viewDidDisappear` which just don't exist in SwiftUI. So I had to write my own. To determine whether a particular view is actually on screen, I needed a couple of `GeometryReaders`. The first one measured the frame of the `List`, while the second measured the frame of the row in the coordinate space of the `List`. If it was within that space (including it's height), then it was on screen. With that determined, each row that was on screen was added to a set of rows on screen. If a row went off screen, and was already within the set, it was removed. This is tested on almost every redraw.

Now that I know what views are on screen, I could then scroll the view so the last partial view is shown completely on screen using the `.bottom` anchor. I call this "SnapTo". It actually is not necessary to the scrolling the view to handle the keyboard, but it makes for a nice look and polish to the view. In order to make SnapTo work after a scroll, I have to track whether the scroll has occurred, wait for it to settle in, and the scroll to the last visibile row. To determine whether the view was scrolling, so I implemented a Comnbine publisher that emitted every time the frame of the `List` changed through the use of a `PreferenceKey`. The preference key reads the origin of the `List` and publishes that value. This publisher then 

Now I had to deal with the keyboard. By determining the keyboard's heaight and publishing a notification with the extensions, I was able to make a keyboard toggle. However, as with all SwiftUI animations, the os reports the position as full height immediately, even though the animation is still running. If you try to scroll while the animation is running, the scroll will end in the incorrect position. As a result, this view has to have an abundance of `DispatchQueue.main.asyncAfter(deadline:)` to time things out. Also, when the view scrolls, that would also trigger the scroll detector to fire, changing which rows are recorded as on screen. So I had to institute a flag, `readCells` that prevents the updating of the set of visible rows. That lock has to remain in place until the `scrollTo` has ended.

This definitely is a favorite funky hack. It is a bit fragile, and hopefully Apple implements this behavior, or at least allows us to set a flag to have this behavior, on `Lists` and `ScrollViews` soon.
