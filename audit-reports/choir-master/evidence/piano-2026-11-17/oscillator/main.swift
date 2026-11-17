import AVFoundation
import Foundation
let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:4096)!
var worst=0.0
for a4 in [300.0,442,500] {
 for index in 0..<97 {
  let frequency=a4*pow(2,(36+Double(index)/2-69)/12)
  let state=ReferenceOscillator();state.setVolume(1);state.play(frequency:frequency)
  var samples:[Float]=[]
  while samples.count<88200 {
   let count=min(4096,88200-samples.count);state.render(count,buffer.mutableAudioBufferList)
   let ptr=buffer.floatChannelData![0]
   for i in 0..<count { precondition(ptr[i].isFinite && abs(ptr[i])<=0.10001 && ptr[i]==buffer.floatChannelData![1][i]) }
   samples.append(contentsOf:UnsafeBufferPointer(start:ptr,count:count))
  }
  var crossings:[Double]=[]
  for i in 2001..<samples.count where samples[i-1]<=0 && samples[i]>0 {
   let x=Double(samples[i-1]),y=Double(samples[i]);crossings.append(Double(i-1)-x/(y-x))
  }
  let measured=Double(crossings.count-1)*44100/(crossings.last!-crossings.first!)
  let cents=abs(1200*log2(measured/frequency));worst=max(worst,cents)
  precondition(cents<0.01,"Pitch \(frequency): \(cents)")
  state.stop();state.render(4096,buffer.mutableAudioBufferList)
  precondition((1000..<4096).allSatisfy { abs(buffer.floatChannelData![0][$0])<0.000001 })
 }
}
let result:[String:Any]=["note_a4_pairs":291,"seconds_each":2,"max_pitch_error_cents":worst,"stop_after_1000_frames":"silent"]
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"/tmp/choir-piano-audit/oscillator-results.json"))
print("PASS: 291 oscillator voices, peak/stereo/stop; worst frequency error \(worst) cents")
