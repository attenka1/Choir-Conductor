package com.attetenkanen.choirmaster.analysis

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

fun main(args: Array<String>) {
    for (name in listOf("stable", "fall", "gap")) {
        val bytes = File(args[0], "$name.pcm").readBytes()
        val shorts = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val pcm = ShortArray(shorts.remaining())
        shorts.get(pcm)
        val points = mutableListOf<AnalysisPoint>()
        val analyzer = PitchAnalysis(22050, 1,
            AnalysisConfig(hopSeconds = .1, blockSeconds = 3.0, stepSeconds = .5), emit = points::add)
        for (start in pcm.indices step 16384)
            analyzer.accept(pcm.copyOfRange(start, minOf(pcm.size, start + 16384)))
        analyzer.finish()
        File(args[0], "$name.android.tsv").printWriter().use { out ->
            for (p in points) out.println("${p.frame}\t${p.cents}\t${p.evidence}\t${p.segment}\t${p.reason}")
        }
    }
}
