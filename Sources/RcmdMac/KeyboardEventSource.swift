@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import Foundation

public final class KeyboardEventSource: @unchecked Sendable {
  public typealias Handler = @Sendable (String) -> Void
  public typealias TriggerHandler = @Sendable (Bool) -> Void

  private let handler: Handler
  private let triggerHandler: TriggerHandler?
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var rightOptionHeld = false

  public init(
    handler: @escaping Handler,
    triggerHandler: TriggerHandler? = nil
  ) {
    self.handler = handler
    self.triggerHandler = triggerHandler
  }

  deinit {
    stop()
  }

  @discardableResult
  public func start() -> Bool {
    guard eventTap == nil else { return true }
    let mask = CGEventMask(
      (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
    )
    let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: Self.callback,
        userInfo: opaqueSelf
      )
    else { return false }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    eventTap = tap
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  public func stop() {
    if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    eventTap = nil
    runLoopSource = nil
    if rightOptionHeld {
      rightOptionHeld = false
      triggerHandler?(false)
    }
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
      return Unmanaged.passUnretained(event)
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    if type == .flagsChanged, keyCode == 61 {
      let isHeld = event.flags.contains(.maskAlternate)
      if isHeld != rightOptionHeld {
        rightOptionHeld = isHeld
        triggerHandler?(isHeld)
      }
      return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, rightOptionHeld, let key = letter(from: event) else {
      return Unmanaged.passUnretained(event)
    }
    handler(key)
    return nil
  }

  private func letter(from event: CGEvent) -> String? {
    guard let nsEvent = NSEvent(cgEvent: event),
      let character = nsEvent.charactersIgnoringModifiers?.lowercased().first,
      character.isLetter
    else { return nil }
    return String(character)
  }

  private nonisolated static let callback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let source = Unmanaged<KeyboardEventSource>.fromOpaque(userInfo).takeUnretainedValue()
    return source.handle(type: type, event: event)
  }
}
