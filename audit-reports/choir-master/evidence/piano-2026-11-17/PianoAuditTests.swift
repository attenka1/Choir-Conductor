import XCTest
import UIKit
@testable import Choir_Master
@MainActor final class PianoAuditTests:XCTestCase {
 func testNoteRangeSustainToggleCancellationAndReferenceState() {
  let domain=Bundle.main.bundleIdentifier!, saved=UserDefaults.standard.persistentDomain(forName:Bundle.main.bundleIdentifier!) ?? [:]
  let state=ConductorModel()
  defer {state.stopAll();UserDefaults.standard.setPersistentDomain(saved,forName:domain)}
  state.pianoVolume=0;state.clickVolume=0;state.soundMode = .piano;state.sustain=false
  for index in 0..<97 {
   let note=36+Double(index)/2
   state.noteDown(note);XCTAssertEqual(state.sounding,[note])
   state.noteUp(note);XCTAssertTrue(state.sounding.isEmpty)
  }
  for note in [Double.nan,Double.infinity,35.5,84.5,60.25] {state.noteDown(note);XCTAssertTrue(state.sounding.isEmpty)}
  state.sustain=true
  for note in [60.0,64,67] {state.noteDown(note);state.noteUp(note)}
  XCTAssertEqual(state.sounding,[60,64,67])
  state.noteDown(60);state.noteUp(60);XCTAssertEqual(state.sounding,[64,67])
  state.sustain=false;XCTAssertTrue(state.sounding.isEmpty)
  state.sustain=true;state.noteDown(69);state.noteCancelled(69);XCTAssertTrue(state.sounding.isEmpty)
  state.soundMode = .reference;state.noteDown(69);state.noteUp(69);XCTAssertEqual(state.sounding,[69])
  state.noteDown(72);XCTAssertEqual(state.sounding,[72]);state.noteCancelled(72);XCTAssertTrue(state.sounding.isEmpty)
 }
 func testAllKeyboardRangesAndQuarterToneGeometry() throws {
  for start in [36,48,60] {
   for divisions in [12,24] {
    let scroll=KeyboardScrollView(frame:CGRect(x:0,y:0,width:390,height:180))
    scroll.configure(start:start,sounding:[],names:NoteNaming.pitchClasses(international:true),divisions:divisions)
    scroll.layoutIfNeeded();scroll.keyboard.layoutIfNeeded()
    let elements=try XCTUnwrap(scroll.keyboard.accessibilityElements as? [UIAccessibilityElement])
    XCTAssertEqual(elements.count,divisions==24 ? 49:25)
    var played:[Double]=[];scroll.keyboard.down={played.append($0)}
    for element in elements {XCTAssertTrue(element.accessibilityActivate())}
    XCTAssertEqual(played.sorted(),(0...(divisions==24 ? 48:24)).map {Double(start)+Double($0)*(divisions==24 ? 0.5:1)})
    for key in elements {
     XCTAssertGreaterThan(key.accessibilityFrameInContainerSpace.width,0)
     XCTAssertGreaterThan(key.accessibilityFrameInContainerSpace.height,0)
     if divisions==24 {XCTAssertGreaterThanOrEqual(key.accessibilityFrameInContainerSpace.width,44-0.001)}
    }
   }
  }
 }
}
