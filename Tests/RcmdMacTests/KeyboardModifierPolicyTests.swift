import CoreGraphics
import Testing

@testable import RcmdMac

@Test func assignedLetterRequiresPhysicalRightOption() {
  var policy = KeyboardModifierPolicy()

  #expect(!policy.allowsAssignedLetter(flags: [.maskAlternate]))

  #expect(
    policy.flagsChanged(
      keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
      flags: [.maskAlternate]
    ) == true
  )
  #expect(policy.allowsAssignedLetter(flags: [.maskAlternate]))

  #expect(
    policy.flagsChanged(
      keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
      flags: []
    ) == false
  )
  #expect(!policy.allowsAssignedLetter(flags: []))
}

@Test(arguments: [
  CGEventFlags.maskCommand,
  .maskControl,
  .maskShift,
  .maskSecondaryFn,
])
func conflictingShortcutModifierPassesAssignedLetterThrough(conflictingFlag: CGEventFlags) {
  var policy = KeyboardModifierPolicy()
  _ = policy.flagsChanged(
    keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
    flags: [.maskAlternate]
  )

  #expect(
    !policy.allowsAssignedLetter(flags: [.maskAlternate, conflictingFlag])
  )
}

@Test func capsLockAndIncidentalFlagsDoNotConflictWithAssignedLetter() {
  var policy = KeyboardModifierPolicy()
  let allowedFlags: CGEventFlags = [
    .maskAlternate,
    .maskAlphaShift,
    .maskNumericPad,
    .maskNonCoalesced,
  ]

  #expect(
    policy.flagsChanged(
      keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
      flags: allowedFlags
    ) == true
  )
  #expect(policy.allowsAssignedLetter(flags: allowedFlags))
}

@Test func previewCancelsAndRearmsAsConflictingModifierChanges() {
  var policy = KeyboardModifierPolicy()

  #expect(
    policy.flagsChanged(
      keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
      flags: [.maskAlternate]
    ) == true
  )
  #expect(
    policy.flagsChanged(
      keyCode: 55,
      flags: [.maskAlternate, .maskCommand]
    ) == false
  )
  #expect(
    policy.flagsChanged(
      keyCode: 55,
      flags: [.maskAlternate]
    ) == true
  )
}

@Test func previewDoesNotRearmAfterRightOptionIsReleasedDuringConflict() {
  var policy = KeyboardModifierPolicy()
  _ = policy.flagsChanged(
    keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
    flags: [.maskAlternate]
  )
  _ = policy.flagsChanged(
    keyCode: 55,
    flags: [.maskAlternate, .maskCommand]
  )

  #expect(
    policy.flagsChanged(
      keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
      flags: [.maskCommand]
    ) == nil
  )
  #expect(
    policy.flagsChanged(
      keyCode: 55,
      flags: []
    ) == nil
  )
  #expect(!policy.previewEligible)
}

@Test func incidentalFlagChangesDoNotCancelPreview() {
  var policy = KeyboardModifierPolicy()
  _ = policy.flagsChanged(
    keyCode: KeyboardModifierPolicy.rightOptionKeyCode,
    flags: [.maskAlternate]
  )

  #expect(
    policy.flagsChanged(
      keyCode: 57,
      flags: [.maskAlternate, .maskAlphaShift, .maskNonCoalesced]
    ) == nil
  )
  #expect(policy.previewEligible)
}
