import AVFoundation
import Foundation
func rms(_ data:[Float]) -> Double { sqrt(data.reduce(0) { $0 + Double($1)*Double($1) } / Double(data.count)) }
var results:[[String:Any]]=[]
for sound in [ReferenceSound.precise, .soundFont] {
    for immediate in [true,false] {
        let engine=AVAudioEngine()
        let tone=try ReferenceTone(engine:engine,soundFontURL:URL(fileURLWithPath:CommandLine.arguments[1]))
        let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
        try engine.enableManualRenderingMode(.offline,format:format,maximumFrameCount:512)
        try engine.start()
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:512)!
        tone.configure(tuning:442,volume:0.7,sound:sound)
        // Intentionally no await between Play and Stop: cancellation before the task begins.
        tone.play(69)
        tone.stop(immediately:immediate)
        try await Task.sleep(for:.milliseconds(80))
        var samples:[Float]=[]
        for _ in 0..<172 {
            let status = try engine.renderOffline(512,to:buffer)
            precondition(status == .success)
            samples.append(contentsOf:UnsafeBufferPointer(start:buffer.floatChannelData![0],count:512))
        }
        let tail=rms(Array(samples.suffix(44100)))
        tone.configure(tuning:442,volume:0.7,sound:sound)
        var afterConfigure:[Float]=[]
        for _ in 0..<86 {
            let status=try engine.renderOffline(512,to:buffer)
            precondition(status == .success)
            afterConfigure.append(contentsOf:UnsafeBufferPointer(start:buffer.floatChannelData![0],count:512))
        }
        let configuredTail=rms(afterConfigure)
        results.append(["rms_after_later_configure":configuredTail,"sound":sound.rawValue,"immediate":immediate,"tail_rms_after_play_stop":tail,
                        "stopped":tail<0.00001,"font_available":tone.soundFontAvailable])
        print("CHARACTERIZATION: \(sound.rawValue), immediate=\(immediate), tail RMS=\(tail), stopped=\(tail<0.00001), later configure RMS=\(configuredTail)")
        tone.stop(immediately:true)
        engine.stop()
    }
}
let bytes=try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys])
try bytes.write(to:URL(fileURLWithPath:"/tmp/choir-piano-audit/reference-cancel.json"))
