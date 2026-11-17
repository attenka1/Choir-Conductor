import AVFoundation
import Foundation
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let metadata=try PianoSampleMetadata.load(from:root.appendingPathComponent("metadata.json"))
var sources:[[Float]]=[]
for item in metadata {
    let file=try AVAudioFile(forReading:root.appendingPathComponent(item.filename))
    let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(file.length))!
    try file.read(into:buffer)
    precondition(Int(file.length)==item.frames && file.processingFormat.sampleRate==44100 && file.processingFormat.channelCount==2)
    sources.append((0..<Int(buffer.frameLength)).map {(buffer.floatChannelData![0][$0]+buffer.floatChannelData![1][$0])/2})
}
let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:4096)!
func renderer(a4:Double=442)->AudioRenderer {
    let state=AudioRenderer();state.samples=sources
    for (i,item) in metadata.enumerated() {
        state.loopEnds[i]=Double(item.loopEndFrame);state.loopLengths[i]=item.loopLengthFrames;state.crossfades[i]=Double(item.crossfadeFrames)
    }
    let pitches=(0..<97).map { index -> Double in
        let note=36+Double(index)/2, source=min(79,max(55,Int(note.rounded())))
        return a4*pow(2,(note-69)/12)/metadata[source-55].fundamentalHz
    }
    state.configure(tempo:80,beats:4,piano:0.7,click:0,pitches:pitches)
    return state
}
func render(_ state:AudioRenderer,_ count:Int)->[Float] {
    state.render(count,buffer.mutableAudioBufferList)
    let a=buffer.floatChannelData![0],b=buffer.floatChannelData![1]
    for i in 0..<count { precondition(a[i].isFinite && abs(a[i])<1 && a[i]==b[i]) }
    return Array(UnsafeBufferPointer(start:a,count:count))
}
let captures=URL(fileURLWithPath:"/tmp/choir-piano-audit/pcm",isDirectory:true)
try FileManager.default.createDirectory(at:captures,withIntermediateDirectories:true)
var rows="index,note,target_hz,a4,peak,release_peak\n"
for a4 in [300.0,442,500] {
    for index in 0..<97 {
        let state=renderer(a4:a4), note=36+Double(index)/2
        state.startNotes([note])
        var samples:[Float]=[]
        while samples.count<132300 { samples += render(state,min(4096,132300-samples.count)) }
        precondition(state.voices[index].gain>0.999 && state.voices[index].held)
        state.releaseNote(note)
        for _ in 0..<3 { _=render(state,4096) }
        let release=render(state,512).map{abs($0)}.max()!
        precondition(release<0.00001)
        let peak=samples.map{abs($0)}.max()!
        precondition(peak>0.0001)
        if a4==442 { try samples.withUnsafeBytes { try Data($0).write(to:captures.appendingPathComponent("\(index).f32")) } }
        rows += "\(index),\(note),\(a4*pow(2,(note-69)/12)),\(a4),\(peak),\(release)\n"
    }
}
try rows.write(toFile:"/tmp/choir-piano-audit/dsp-results.csv",atomically:true,encoding:.utf8)
// Output independent of callback buffer size for a sustained voice.
let a=renderer(),b=renderer();a.startNotes([36,69.5,84]);b.startNotes([36,69.5,84])
var x:[Float]=[],y:[Float]=[]
while x.count<88200 { x += render(a,min(4096,88200-x.count)) }
var cycle=0
while y.count<88200 { let n=[1,17,512,389][cycle%4];y += render(b,min(n,88200-y.count));cycle+=1 }
precondition(x==y)
// Correctly wrapping even a playback step larger than a loop, using only validated loop bounds.
let huge=renderer();huge.configure(tempo:80,beats:4,piano:0.7,click:0,pitches:Array(repeating:50000,count:97));huge.startNotes([60])
_=render(huge,4096)
// Exact envelope characterization on a constant synthetic sample.
let env=AudioRenderer();env.samples=Array(repeating:Array(repeating:Float(0.25),count:44100),count:25)
env.configure(tempo:80,beats:4,piano:1,click:0,pitches:nil);env.startNotes([69]);_=render(env,220)
precondition(abs(env.voices[66].gain-1)<0.00002)
let before=render(env,1)[0]
env.configure(tempo:80,beats:4,piano:0,click:0,pitches:nil)
let after=render(env,1)[0]
let data:[String:Any]=["tested_note_a4_pairs":291,"frames_per_voice":132300,"source_files":metadata.count,
  "buffer_invariance":true,"large_step_wrap":true,"attack_gain_after_220_frames":env.voices[66].gain,
  "volume_step_previous_sample":before,"volume_step_next_sample":after]
try JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"/tmp/choir-piano-audit/dsp-summary.json"))
print("PASS: 291 piano note/A4 pairs, 3s sustain each, releases, bounds, stereo, buffer invariance and large-step wrapping")
