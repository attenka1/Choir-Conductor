import Foundation

nonisolated enum Temperament: String, CaseIterable, Codable, Sendable {
    case equal, just, pythagorean, quarterComma, werckmeisterIII, kirnbergerIII, vallotti
    var title: String {
        switch self {
        case .equal: return T("Tasavireinen")
        case .just: return T("Luonnonvire")
        case .werckmeisterIII: return "Werckmeister III"
        case .kirnbergerIII: return "Kirnberger III"
        case .vallotti: return "Vallotti"
        case .pythagorean: return T("Pythagoralainen")
        case .quarterComma: return T("¼-komman keskisävel")
        }
    }
    var explanation: String {
        switch self {
        case .equal: return T("Tasaiset sävelvälit. Sopii yleiskäyttöön ja 24 sävelen asteikkoon.")
        case .just: return T("Puhtaat suhteet valitusta pohjasävelestä: duuriterssi 5:4, molliterssi 6:5 ja kvintti 3:2. Sopii kuoron sointuharjoitteluun. Viritys on kiinteä: vaihda pohjasäveltä harmonian mukaan. Kaikki muiden pohjasävelten soinnut eivät ole puhtaita.")
        case .pythagorean: return T("Puhtaat kvintit. Korostaa melodisia intervalleja; duuriterssit ovat luonnonvirettä korkeampia. Kvinttiketjun päiden välissä on susikvintti.")
        case .quarterComma: return T("Puhtaat duuriterssit ja kavennetut kvintit. Sopii renessanssiin ja varhaiseen barokkiin. Kvinttiketjun päiden välissä on susikvintti.")
        case .werckmeisterIII: return T("Neljä kvinttiä on kavennettu ¼ pythagoralaisella kommalla. Historiallinen kiertävä viritys: sävellajeilla on erilainen väri.")
        case .kirnbergerIII: return T("Neljä kvinttiä on kavennettu ¼ syntonisella kommalla; yksi kvintti korjaa skisman. C-pohjalla C–E-terssi on puhdas.")
        case .vallotti: return T("Kuusi kvinttiä on kavennettu ⅙ pythagoralaisella kommalla. Kiertävä viritys myöhäisbarokin ja klassisen ohjelmiston harjoitteluun.")
        }
    }
    var usesOpenChain: Bool { self == .pythagorean || self == .quarterComma }

    private func offset(pitchClass: Int) -> Double {
        let pureFifth = 1200 * log2(1.5)
        let pythagoreanComma = 12 * pureFifth - 7 * 1200
        let syntonicComma = 1200 * log2(81.0 / 80)
        switch self {
        case .equal: return 0
        case .just:
            // One explicitly chosen chromatic extension of 5-limit major/minor scales.
            let ratios: [Double] = [1.0, 16.0/15, 9.0/8, 6.0/5, 5.0/4, 4.0/3,
                          45.0/32, 3.0/2, 8.0/5, 5.0/3, 9.0/5, 15.0/8]
            return 1200 * log2(ratios[pitchClass]) - Double(pitchClass) * 100
        case .pythagorean, .quarterComma:
            // C root: E♭–B♭–F–C–G–D–A–E–B–F♯–C♯–G♯ (−3...8 fifths).
            let index = (-3...8).first { (($0 * 7) % 12 + 12) % 12 == pitchClass }!
            let fifth = self == .pythagorean ? pureFifth : 300 * log2(5)
            return Double(index) * (fifth - 700)
        case .werckmeisterIII, .kirnbergerIII, .vallotti:
            var cents = 0.0
            // Closed fifth circle C–G–D–A–E–B–F♯–C♯–G♯–E♭–B♭–F–C.
            for index in 0..<12 {
                let lower = (index * 7) % 12
                if lower == pitchClass { return cents }
                let narrowing: Double
                switch self {
                case .werckmeisterIII:
                    narrowing = [0, 7, 2, 11].contains(lower) ? pythagoreanComma / 4 : 0
                case .kirnbergerIII:
                    narrowing = [0, 7, 2, 9].contains(lower) ? syntonicComma / 4 :
                        (lower == 6 ? pythagoreanComma - syntonicComma : 0)
                default:
                    narrowing = [5, 0, 7, 2, 9, 4].contains(lower) ? pythagoreanComma / 6 : 0
                }
                cents += pureFifth - narrowing - 700
            }
            return 0
        }
    }
    func correction(note: Double, root: Int) -> Double {
        func relativeClass(_ midi: Int) -> Int { ((midi - root) % 12 + 12) % 12 }
        // Normalize every system to the selected A4, including transposed systems.
        return offset(pitchClass: relativeClass(Int(note.rounded(.down)))) - offset(pitchClass: relativeClass(69))
    }
    func frequency(note: Double, a4: Double, root: Int) -> Double {
        a4 * pow(2, (note - 69) / 12 + correction(note: note, root: root) / 1200)
    }
}
