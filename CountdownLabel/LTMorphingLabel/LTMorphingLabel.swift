//
//  LTMorphingLabel.swift
//  https://github.com/lexrus/LTMorphingLabel
//
//  The MIT License (MIT)
//  Copyright (c) 2017 Lex Tang, http://lexrus.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files
//  (the “Software”), to deal in the Software without restriction,
//  including without limitation the rights to use, copy, modify, merge,
//  publish, distribute, sublicense, and/or sell copies of the Software,
//  and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import UIKit
import QuartzCore

private func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

private func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}

enum LTMorphingPhases: Int {
    case start, appear, disappear, draw, progress, skipFrames
}

typealias LTMorphingStartClosure =
    () -> Void

typealias LTMorphingEffectClosure =
    (Character, _ index: Int, _ progress: Float) -> LTCharacterLimbo

typealias LTMorphingDrawingClosure =
    (LTCharacterLimbo) -> Bool

typealias LTMorphingManipulateProgressClosure =
    (_ index: Int, _ progress: Float, _ isNewChar: Bool) -> Float

typealias LTMorphingSkipFramesClosure =
    () -> Int

@objc public protocol LTMorphingLabelDelegate {
    @objc optional func morphingDidStart(_ label: LTMorphingLabel)
    @objc optional func morphingDidComplete(_ label: LTMorphingLabel)
    @objc optional func morphingOnProgress(_ label: LTMorphingLabel, progress: Float)
}

// MARK: - LTMorphingLabel
open class LTMorphingLabel: UILabel {
    
    var morphingProgress: Float = 0.0
    var morphingDuration: Float = 0.6
    var morphingCharacterDelay: Float = 0.026
    var morphingEnabled: Bool = true

    @IBOutlet open weak var delegate: LTMorphingLabelDelegate?
    open var morphingEffect: LTMorphingEffect = .scale
    
    var startClosures = [String: LTMorphingStartClosure]()
    var effectClosures = [String: LTMorphingEffectClosure]()
    var drawingClosures = [String: LTMorphingDrawingClosure]()
    var progressClosures = [String: LTMorphingManipulateProgressClosure]()
    var skipFramesClosures = [String: LTMorphingSkipFramesClosure]()
    var diffResults: LTStringDiffResult?
    var previousText: NSAttributedString?
    
    var currentFrame = 0
    var totalFrames = 0
    var totalDelayFrames = 0
    
    var totalWidth: Float = 0.0
    var previousRects = [CGRect]()
    var newRects = [CGRect]()
    var charHeight: CGFloat = 0.0
    var skipFramesCount: Int = 0
    
    #if TARGET_INTERFACE_BUILDER
    let presentingInIB = true
    #else
    let presentingInIB = false
    #endif
    
    override open var font: UIFont! {
        get {
            return super.font ?? UIFont.systemFont(ofSize: 15)
        }
        set {
            super.font = newValue
            setNeedsLayout()
        }
    }
    
    open override var text: String? {
        get {
            return super.text
        }
        set {
            if let newValue = newValue {
                attributedText = NSAttributedString(string: newValue, attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: textColor
                    ])
            } else {
                attributedText = nil
            }
            
        }
    }
    
    open override var attributedText: NSAttributedString? {
        get {
            return super.attributedText
        }
        set {
            guard attributedText != newValue else { return }

            previousText = attributedText
            diffResults = previousText?.string.diffWith(newValue?.string)
            super.attributedText = newValue
            
            morphingProgress = 0.0
            currentFrame = 0
            totalFrames = 0
            
            setNeedsLayout()
            
            if !morphingEnabled {
                return
            }
            
            if presentingInIB {
                morphingDuration = 0.01
                morphingProgress = 0.5
            } else if previousText != attributedText {
                displayLink.isPaused = false
                let closureKey = "\(morphingEffect.description)\(LTMorphingPhases.start)"
                if let closure = startClosures[closureKey] {
                    return closure()
                }
                
                delegate?.morphingDidStart?(self)
            }
        }
    }
    
    open override func setNeedsLayout() {
        super.setNeedsLayout()
        if let previous = previousText {
            previousRects = rectsOfEachCharacter(previous)
        }
        if let newAttributed = attributedText {
            newRects = rectsOfEachCharacter(newAttributed)
        }
        
    }
    
    override open var bounds: CGRect {
        get {
            return super.bounds
        }
        set {
            super.bounds = newValue
            setNeedsLayout()
        }
    }
    
    override open var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            setNeedsLayout()
        }
    }
    
    fileprivate lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(LTMorphingLabel.displayFrameTick)
        )
        displayLink.add(to: .current, forMode: .common)
        return displayLink
        }()

    deinit {
        displayLink.remove(from: .current, forMode: .common)
        displayLink.invalidate()
    }
    
    lazy var emitterView: LTEmitterView = {
        let emitterView = LTEmitterView(frame: self.bounds)
        self.addSubview(emitterView)
        return emitterView
        }()
}

// MARK: - Animation extension
extension LTMorphingLabel {

    @objc func displayFrameTick() {
        if displayLink.duration > 0.0 && totalFrames == 0 {
            var frameRate = Float(0)
            if #available(iOS 10.0, tvOS 10.0, *) {
                var frameInterval = 1
                if displayLink.preferredFramesPerSecond == 60 {
                    frameInterval = 1
                } else if displayLink.preferredFramesPerSecond == 30 {
                    frameInterval = 2
                } else {
                    frameInterval = 1
                }
                frameRate = Float(displayLink.duration) / Float(frameInterval)
            } else {
                frameRate = Float(displayLink.duration) / Float(displayLink.frameInterval)
            }
            totalFrames = Int(ceil(morphingDuration / frameRate))

            let totalDelay = Float((attributedText!.string).count) * morphingCharacterDelay
            totalDelayFrames = Int(ceil(totalDelay / frameRate))
        }

        currentFrame += 1

        if previousText != attributedText && currentFrame < totalFrames + totalDelayFrames + 5 {
            morphingProgress += 1.0 / Float(totalFrames)

            let closureKey = "\(morphingEffect.description)\(LTMorphingPhases.skipFrames)"
            if let closure = skipFramesClosures[closureKey] {
                skipFramesCount += 1
                if skipFramesCount > closure() {
                    skipFramesCount = 0
                    setNeedsDisplay()
                }
            } else {
                setNeedsDisplay()
            }

            if let onProgress = delegate?.morphingOnProgress {
                onProgress(self, morphingProgress)
            }
        } else {
            displayLink.isPaused = true

            delegate?.morphingDidComplete?(self)
        }
    }
    
    // Could be enhanced by kerning text:
    // http://stackoverflow.com/questions/21443625/core-text-calculate-letter-frame-in-ios
    func rectsOfEachCharacter(_ textToDraw: NSAttributedString) -> [CGRect] {
        var charRects = [CGRect]()
        var leftOffset: CGFloat = 0.0
        
        for i in 0..<textToDraw.string.count {
            let char = textToDraw.string[i]
            let charAttributes = attributes(at: i)
            let charHeight = String(char).size(withAttributes: charAttributes).height
            let topOffset = (intrinsicContentSize.height - charHeight) - (bounds.height - charHeight) / 4
            let charSize = String(char).size(withAttributes: charAttributes)
            charRects.append(
                CGRect(
                    origin: CGPoint(
                        x: leftOffset,
                        y: topOffset
                    ),
                    size: charSize
                )
            )
            leftOffset += charSize.width
        }
        
        totalWidth = Float(leftOffset)
        
        var stringLeftOffSet: CGFloat = 0.0
        
        switch textAlignment {
        case .center:
            stringLeftOffSet = CGFloat((Float(bounds.size.width) - totalWidth) / 2.0)
        case .right:
            stringLeftOffSet = CGFloat(Float(bounds.size.width) - totalWidth)
        default:
            ()
        }
        
        var offsetedCharRects = [CGRect]()
        
        for r in charRects {
            offsetedCharRects.append(r.offsetBy(dx: stringLeftOffSet, dy: 0.0))
        }
        
        return offsetedCharRects
    }
    
    func limboOfOriginalCharacter(
        _ char: Character,
        index: Int,
        progress: Float) -> LTCharacterLimbo {
            
            var currentRect = previousRects[index]
            let oriX = Float(currentRect.origin.x)
            var newX = Float(currentRect.origin.x)
            let diffResult = diffResults!.0[index]
            var currentFontSize: CGFloat = font.pointSize
            var currentAlpha: CGFloat = 1.0
            
            switch diffResult {
                // Move the character that exists in the new text to current position
            case .same:
                newX = Float(newRects[index].origin.x)
                currentRect.origin.x = CGFloat(
                    LTEasing.easeOutQuint(progress, oriX, newX - oriX)
                )
            case .move(let offset):
                newX = Float(newRects[index + offset].origin.x)
                currentRect.origin.x = CGFloat(
                    LTEasing.easeOutQuint(progress, oriX, newX - oriX)
                )
            case .moveAndAdd(let offset):
                newX = Float(newRects[index + offset].origin.x)
                currentRect.origin.x = CGFloat(
                    LTEasing.easeOutQuint(progress, oriX, newX - oriX)
                )
            default:
                // Otherwise, remove it
                
                // Override morphing effect with closure in extenstions
                if let closure = effectClosures[
                    "\(morphingEffect.description)\(LTMorphingPhases.disappear)"
                    ] {
                        return closure(char, index, progress)
                } else {
                    // And scale it by default
                    let fontEase = CGFloat(
                        LTEasing.easeOutQuint(
                            progress, 0, Float(font.pointSize)
                        )
                    )
                    // For emojis
                    currentFontSize = max(0.0001, font.pointSize - fontEase)
                    currentAlpha = CGFloat(1.0 - progress)
                    currentRect = previousRects[index].offsetBy(
                        dx: 0,
                        dy: CGFloat(font.pointSize - currentFontSize)
                    )
                }
            }
            
            return LTCharacterLimbo(
                char: char,
                rect: currentRect,
                alpha: currentAlpha,
                size: currentFontSize,
                drawingProgress: 0.0,
                attributes: attributes(at: index)
            )
    }
    
    func attributes(at index: Int) -> [NSAttributedString.Key: Any] {
        let attr = attributedText?.attributes(at: index, effectiveRange: nil)
        return attr ?? [.foregroundColor: textColor, .font: font]
    }
    
    func limboOfNewCharacter(
        _ char: Character,
        index: Int,
        progress: Float) -> LTCharacterLimbo {
            
            let currentRect = newRects[index]
            var currentFontSize = CGFloat(
                LTEasing.easeOutQuint(progress, 0, Float(font.pointSize))
            )
            
            if let closure = effectClosures[
                "\(morphingEffect.description)\(LTMorphingPhases.appear)"
                ] {
                    return closure(char, index, progress)
            } else {
                currentFontSize = CGFloat(
                    LTEasing.easeOutQuint(progress, 0.0, Float(font.pointSize))
                )
                // For emojis
                currentFontSize = max(0.0001, currentFontSize)
                
                let yOffset = CGFloat(font.pointSize - currentFontSize)
                
                return LTCharacterLimbo(
                    char: char,
                    rect: currentRect.offsetBy(dx: 0, dy: yOffset),
                    alpha: CGFloat(morphingProgress),
                    size: currentFontSize,
                    drawingProgress: 0.0,
                    attributes: attributes(at: index)
                )
            }
    }
    
    func limboOfCharacters() -> [LTCharacterLimbo] {
        var limbo = [LTCharacterLimbo]()
        
        // Iterate original characters
        if let previous = previousText {
            for (i, character) in previous.string.enumerated() {
                var progress: Float = 0.0
                
                if let closure = progressClosures[
                    "\(morphingEffect.description)\(LTMorphingPhases.progress)"
                    ] {
                    progress = closure(i, morphingProgress, false)
                } else {
                    progress = min(1.0, max(0.0, morphingProgress + morphingCharacterDelay * Float(i)))
                }
                
                let limboOfCharacter = limboOfOriginalCharacter(character, index: i, progress: progress)
                limbo.append(limboOfCharacter)
            }
        }
        
        
        // Add new characters
        if let newAttributed = attributedText {
            for (i, character) in newAttributed.string.enumerated() {
                if i >= diffResults?.0.count {
                    break
                }
                
                var progress: Float = 0.0
                
                if let closure = progressClosures[
                    "\(morphingEffect.description)\(LTMorphingPhases.progress)"
                    ] {
                    progress = closure(i, morphingProgress, true)
                } else {
                    progress = min(1.0, max(0.0, morphingProgress - morphingCharacterDelay * Float(i)))
                }
                
                // Don't draw character that already exists
                if diffResults?.skipDrawingResults[i] == true {
                    continue
                }
                
                if let diffResult = diffResults?.0[i] {
                    switch diffResult {
                    case .moveAndAdd, .replace, .add, .delete:
                        let limboOfCharacter = limboOfNewCharacter(
                            character,
                            index: i,
                            progress: progress
                        )
                        limbo.append(limboOfCharacter)
                    default:
                        ()
                    }
                }
            }
        }
        
        
        return limbo
    }

}

// MARK: - Drawing extension
extension LTMorphingLabel {
    
    override open func didMoveToSuperview() {
        if let s = text {
            text = s
        }
        
        // Load all morphing effects
        for effectName: String in LTMorphingEffect.allValues {
            let effectFunc = Selector("\(effectName)Load")
            if responds(to: effectFunc) {
                perform(effectFunc)
            }
        }
    }
    
    override open func drawText(in rect: CGRect) {
        let limbo = limboOfCharacters()
        if !morphingEnabled || limbo.count == 0 {
            super.drawText(in: rect)
            return
        }
        
        for charLimbo in limbo {
            let charRect = charLimbo.rect
            let willAvoidDefaultDrawing: Bool = {
                if let closure = drawingClosures[
                    "\(morphingEffect.description)\(LTMorphingPhases.draw)"
                    ] {
                        return closure($0)
                }
                return false
                }(charLimbo)

            if !willAvoidDefaultDrawing {
                var attrs: [NSAttributedString.Key: Any] = charLimbo.attributes
                let tColor = attrs[NSAttributedString.Key.foregroundColor] as? UIColor ?? textColor
                attrs[.foregroundColor] = tColor?.withAlphaComponent(charLimbo.alpha)
                if attrs[.font] == nil {
                    attrs[.font] = font
                }

                let s = String(charLimbo.char)
                s.draw(in: charRect, withAttributes: attrs)
            }
        }
    }
}

extension String {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    subscript (bounds: CountableRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ..< end]
    }
    subscript (bounds: CountableClosedRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ... end]
    }
    subscript (bounds: CountablePartialRangeFrom<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(endIndex, offsetBy: -1)
        return self[start ... end]
    }
    subscript (bounds: PartialRangeThrough<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ... end]
    }
    subscript (bounds: PartialRangeUpTo<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ..< end]
    }
}
extension Substring {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    subscript (bounds: CountableRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ..< end]
    }
    subscript (bounds: CountableClosedRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ... end]
    }
    subscript (bounds: CountablePartialRangeFrom<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(endIndex, offsetBy: -1)
        return self[start ... end]
    }
    subscript (bounds: PartialRangeThrough<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ... end]
    }
    subscript (bounds: PartialRangeUpTo<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ..< end]
    }
}
