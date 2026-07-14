import Cocoa
import FlutterMacOS
import XCTest
@testable import aitrans

class RunnerTests: XCTestCase {

  func testBundleDeclaresHostCompatibleTextService() throws {
    let services = try XCTUnwrap(
      Bundle.main.object(forInfoDictionaryKey: "NSServices") as? [[String: Any]]
    )
    let service = try XCTUnwrap(services.first)
    let menuItem = try XCTUnwrap(service["NSMenuItem"] as? [String: String])

    XCTAssertEqual(services.count, 1)
    XCTAssertEqual(menuItem["default"], "使用 AITrans 翻译")
    XCTAssertEqual(service["NSMessage"] as? String, "translateSelection")
    XCTAssertEqual(service["NSSendTypes"] as? [String], ["NSStringPboardType"])
  }

  func testServiceParserAcceptsExactlyOnePlainTextItem() throws {
    let pasteboard = NSPasteboard(name: .init("test.valid.\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects(["selected text" as NSString])

    let text = try ServicePasteboardParser.parse(pasteboard)

    XCTAssertEqual(text, "selected text")
  }

  func testServiceParserRejectsMissingPlainText() {
    let pasteboard = NSPasteboard(name: .init("test.missing.\(UUID().uuidString)"))
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(Data([0x01]), forType: .init("com.aitrans.unsupported"))
    pasteboard.writeObjects([item])

    XCTAssertThrowsError(try ServicePasteboardParser.parse(pasteboard)) { error in
      XCTAssertEqual(error as? ServiceRequestError, .plainTextUnavailable)
      XCTAssertFalse(error.localizedDescription.contains("selected"))
    }
  }

  func testServiceParserRejectsMultipleItems() {
    let pasteboard = NSPasteboard(name: .init("test.multiple.\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects(["first" as NSString, "second" as NSString])

    XCTAssertThrowsError(try ServicePasteboardParser.parse(pasteboard)) { error in
      XCTAssertEqual(error as? ServiceRequestError, .invalidItemCount)
    }
  }

  func testServiceProviderAssignsMonotonicSequenceAndForwardsText() {
    var requests: [NativeExternalTranslationRequest] = []
    let provider = ExternalTranslationServiceProvider { requests.append($0) }

    provider.translateSelection(makePasteboard(text: "first"), userData: nil, error: nil)
    provider.translateSelection(makePasteboard(text: "second"), userData: nil, error: nil)

    XCTAssertEqual(requests.map(\.sequence), [1, 2])
    XCTAssertEqual(requests.map(\.text), ["first", "second"])
  }

  func testServiceProviderReturnsSafeErrorWithoutForwardingInvalidPayload() {
    var requests: [NativeExternalTranslationRequest] = []
    let provider = ExternalTranslationServiceProvider { requests.append($0) }
    let pasteboard = NSPasteboard(name: .init("test.invalid.\(UUID().uuidString)"))
    pasteboard.clearContents()
    var message: NSString?

    provider.translateSelection(pasteboard, userData: nil, error: &message)

    XCTAssertTrue(requests.isEmpty)
    XCTAssertEqual(message, "AITrans 只能处理单段纯文本。")
  }

  func testRequestBufferKeepsOnlyLatestRequestBeforeFlutterAttaches() {
    let buffer = ExternalTranslationRequestBuffer()
    let first = NativeExternalTranslationRequest(sequence: 1, text: "first")
    let second = NativeExternalTranslationRequest(sequence: 2, text: "second")
    var delivered: [NativeExternalTranslationRequest] = []

    buffer.receive(first)
    buffer.receive(second)
    buffer.attach { delivered.append($0) }

    XCTAssertEqual(delivered, [second])
    XCTAssertNil(buffer.pendingRequest)
  }

  func testRequestBufferDeliversWarmRequestsImmediately() {
    let buffer = ExternalTranslationRequestBuffer()
    var delivered: [NativeExternalTranslationRequest] = []
    buffer.attach { delivered.append($0) }

    buffer.receive(NativeExternalTranslationRequest(sequence: 1, text: "first"))
    buffer.receive(NativeExternalTranslationRequest(sequence: 2, text: "second"))

    XCTAssertEqual(delivered.map(\.sequence), [1, 2])
  }

  private func makePasteboard(text: String) -> NSPasteboard {
    let pasteboard = NSPasteboard(name: .init("test.service.\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects([text as NSString])
    return pasteboard
  }

}
