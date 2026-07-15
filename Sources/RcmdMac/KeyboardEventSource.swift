@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import Foundation

struct KeyboardModifierPolicy {
  static let rightOptionKeyCode: CGKeyCode = 61

  private static let conflictingShortcutModifiers: CGEventFlags = [
    .maskCommand,
    .maskControl,
    .maskShift,
    .maskSecondaryFn,
  ]

  private(set) var rightOptionHeld = false
  private(set) var previewEligible = false

  mutating func flagsChanged(
    keyCode: CGKeyCode,
    flags: CGEventFlags
  ) -> Bool? {
    if keyCode == Self.rightOptionKeyCode {
      rightOptionHeld = flags.contains(.maskAlternate)
    }

    let nextPreviewEligible = Self.isEligible(
      rightOptionHeld: rightOptionHeld,
      flags: flags
    )
    guard nextPreviewEligible != previewEligible else { return nil }

    previewEligible = nextPreviewEligible
    return nextPreviewEligible
  }

  func allowsAssignedLetter(flags: CGEventFlags) -> Bool {
    Self.isEligible(rightOptionHeld: rightOptionHeld, flags: flags)
  }

  mutating func reset() -> Bool? {
    rightOptionHeld = false
    guard previewEligible else { return nil }
    previewEligible = false
    return false
  }

  private static func isEligible(
    rightOptionHeld: Bool,
    flags: CGEventFlags
  ) -> Bool {
    rightOptionHeld
      && flags.intersection(conflictingShortcutModifiers).isEmpty
  }
}

public final class KeyboardEventSource: @unchecked Sendable {
  public typealias Handler = @Sendable (String) -> Void
  public typealias TriggerHandler = @Sendable (Bool) -> Void

  private let handler: Handler
  private let triggerHandler: TriggerHandler?
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var modifierPolicy = KeyboardModifierPolicy()

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
    if let previewEligible = modifierPolicy.reset() {
      triggerHandler?(previewEligible)
    }
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
      return Unmanaged.passUnretained(event)
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    if type == .flagsChanged {
      if let previewEligible = modifierPolicy.flagsChanged(
        keyCode: keyCode,
        flags: event.flags
      ) {
        triggerHandler?(previewEligible)
      }
      return Unmanaged.passUnretained(event)
    }

    guard
      type == .keyDown,
      modifierPolicy.allowsAssignedLetter(flags: event.flags),
      let key = letter(from: event)
    else {
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
