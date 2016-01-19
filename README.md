CountdownLabel
========================

[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Swift 2.0](https://img.shields.io/badge/Swift-2.0-orange.svg?style=flat)](https://developer.apple.com/swift/)

Simple countdown UIlabel with morphing animation, and some useful function.

![sample](Screenshots/example01.gif)

## features
- Simple creation
- Easily get status of countdown from property and delegate.
- Insert some of function, and completion
- Style change as usual as UILabel do
- Morphing animation from [LTMorphingLabel](https://github.com/lexrus/LTMorphingLabel).
- XCTest assertion

## Usage
You need only 2 lines. 

```swift
// from current Date, after 30 minutes.
let countdownLabel = CountdownLabel(frame: frame, minutes: 30) // you can use NSDate as well
countdownLabel.start()
```

#### Morphing example
Use `animationType`.
Those effect come from [LTMorphingLabel](https://github.com/lexrus/LTMorphingLabel).

```swift
let countdownLabel = CountdownLabel(frame: CGRectZero, time: 30)
countdownLabel.animationType = .Pixelate
countdownLabel.start()
```

| morphing effect | example | 
| -------- |--------- | 
| .Burn |  ![sample](Screenshots/exampleBurn.gif) |
| .Evaporate |  ![sample](Screenshots/exampleEvaporate.gif) |
| .Fall |  ![sample](Screenshots/exampleFall.gif) |
| .Pixelate | ![sample](Screenshots/examplePixelate.gif) |   
| .Scale | ![sample](Screenshots/exampleScale.gif) |   
| .Sparkle | ![sample](Screenshots/exampleSparkle.gif) |

#### Style
you can directly allocate it as a normal UILabel property just like usual.

```swift
countdownLabel.textColor = .orangeColor()
countdownLabel.font = UIFont(name:"Courier", size:UIFont.labelFontSize())
countdownLabel.start()
```

![sample](Screenshots/example02.gif) 

#### Get Status of timer
```swift
@IBAction func getTimerCounted(sender: UIButton) {
    debugPrint("\(countdownLabel.timeCounted)")
}

@IBAction func getTimerRemain(sender: UIButton) {
    debugPrint("\(countdownLabel.timeRemaining)")
}
```

![sample](Screenshots/example03.gif) 

#### Control countdown
You can pause, start, add time.

```swift
// check if pause or not
if countdownLabel.isPaused {
    // timer start
    countdownLabel.start()
} else {
    // timer pause
    countdownLabel.pause()
}
```

```swift
// -2 minutes for ending
@IBAction func minus(countdownLabel: UIButton) {
    countdownLabel.addTimeCountedByTime(-2)
}
    
// +2 minutes for ending
@IBAction func plus(countdownLabel: UIButton) {
    countdownLabel.addTimeCountedByTime(2)
}
```

![sample](Screenshots/example04.gif) 

#### Insert Function
Using `then` function or `delegate`, you can set your function anywhere you like.

```swift
countdownLabel.then(10) { [unowned self] in
    self.countdownLabel.animationType = .Pixelate
    self.countdownLabel.textColor = .greenColor()
}
countdownLabel.then(5) { [unowned self] in
    self.countdownLabel.animationType = .Sparkle
    self.countdownLabel.textColor = .yellowColor()
}
countdownLabel.start() {
    self.countdownLabel.textColor = .whiteColor()
}
```

![sample](Screenshots/example06.gif) 

#### Attributed Text
you can set as attributedText too. note:but morphing animation will be disabled.
```
countdownLabel.setCountDownTime(30)
countdownLabel.timeFormat = "ss"
countdownLabel.timerInText = SKTimerInText(text: "timer here in text", replacement: "here")
countdownLabel.start() {
    self.countdownLabel.text = "timer finished."
}
```

![sample](Screenshots/example07.gif) 


#### Format
CountdownLabel uses `00:00:00 (HH:mm:ss)` as default format.
if you prefer using another format, Your can set your time format like below.

`countdownLabel.timeFormat = @"mm:ss"`

#### Scheduled
you can set as scheduled timer

```swift
// 1. schedule
let fromDate   = NSDate().dateByAddingTimeInterval(10)
let targetDate = NSDate().dateByAddingTimeInterval(20)
let upperLabel = CountdownLabel(frame: CGRectZero, fromDate: fromDate, targetDate: targetDate)
upperLabel.start()

// 2. default
let targetDate = NSDate().dateByAddingTimeInterval(30)
let bottomLabel = CountdownLabel(frame: CGRectZero, targetDate: targetDate)
bottomLabel.start()
```

![sample](Screenshots/example08.gif) 

#### Check Status
some public properties are useful. 

```swift
countdownLabel.isCounting      // check timer is counting now
countdownLabel.isPaused        // check timer was stopped
countdownLabel.isFinished      // check timer has ended
countdownLabel.morphingEnabled // check morphing is enabled
```

## Requirements
- iOS 8.0+
- Swift 2.0+
- ARC

##Installation

####CocoaPods
available on CocoaPods. Just add the following to your project Podfile:
```
pod 'CountdownLabel'
use_frameworks!
```

####Carthage
To integrate into your Xcode project using Carthage, specify it in your Cartfile:

```ogdl
github "suzuki-0000/CountdownLabel"
```

## Inspirations
* [LTMorphingLabel](https://github.com/lexrus/LTMorphingLabel) is motivation for creating this.
* [MZTimerLabel](https://github.com/mineschan/MZTimerLabel), in many reference from this project.

## License
available under the MIT license. See the LICENSE file for more info.
