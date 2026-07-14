import Testing

@testable import RcmdMac

@Test(arguments: [
  ("Google Chrome", "Chrome"),
  ("Microsoft Outlook", "Outlook"),
  ("Visual Studio Code", "Visual Studio Code"),
  ("Ghostty", "Ghostty"),
])
func canonicalAppNames(input: String, expected: String) {
  #expect(CanonicalAppName.resolve(input) == expected)
}
