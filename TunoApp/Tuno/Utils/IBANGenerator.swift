import Foundation

/// Konverterer norske kontonumre (BBAN, 11 siffer) til IBAN (NO + 13 siffer)
/// uten å ringe noen ekstern tjeneste. Bruker den deterministiske
/// ISO 13616-formelen og MOD-11-validering på selve kontonummeret.
///
/// Norsk IBAN er alltid `NO` + 2-sifret kontrollsiffer + 11 siffer BBAN,
/// totalt 15 tegn. Stripe godtar denne strengen direkte som external_account
/// for norske utbetalinger.
enum IBANGenerator {

    /// Returnerer IBAN-strengen ("NO9312345678903") hvis kontonummeret er
    /// gyldig, ellers nil. Tomrom og bindestreker fjernes før validering.
    static func ibanFromBBAN(_ bban: String) -> String? {
        let digits = bban.filter(\.isNumber)
        guard digits.count == 11 else { return nil }
        guard isMod11Valid(bban: digits) else { return nil }
        guard let check = ibanCheckDigits(forBBAN: digits) else { return nil }
        return "NO\(check)\(digits)"
    }

    /// Visuell pent-formatering for preview ("NO93 1234 5678 903").
    /// Brukes kun til å vise brukeren hva vi sender — selve IBAN-strengen
    /// må sendes uten mellomrom til Stripe.
    static func formatForDisplay(_ iban: String) -> String {
        let raw = iban.filter { !$0.isWhitespace }
        return stride(from: 0, to: raw.count, by: 4).map { offset -> String in
            let start = raw.index(raw.startIndex, offsetBy: offset)
            let end = raw.index(start, offsetBy: min(4, raw.count - offset))
            return String(raw[start..<end])
        }.joined(separator: " ")
    }

    // MARK: - Internt

    /// Norsk kontonummer-MOD-11 (KID-style):
    /// vekter (5,4,3,2,7,6,5,4,3,2) over de første 10 sifrene, sjekksiffer
    /// = 11 − (sum mod 11). Verdi 11 → 0; 10 er ugyldig kontonummer.
    private static func isMod11Valid(bban: String) -> Bool {
        let digits = bban.compactMap { Int(String($0)) }
        guard digits.count == 11 else { return false }
        let weights = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
        let sum = zip(digits.prefix(10), weights).reduce(0) { $0 + $1.0 * $1.1 }
        var control = 11 - (sum % 11)
        if control == 11 { control = 0 }
        if control == 10 { return false }
        return control == digits[10]
    }

    /// IBAN-kontrollsifre (ISO 13616): rearrange BBAN + "NO00", konverter
    /// bokstaver til tall (N=23, O=24), beregn mod 97 av tallet og returner
    /// 98 − rest som 2-sifret streng.
    ///
    /// Tallet blir for stort for Int64, så vi gjør "running mod 97" siffer
    /// for siffer i stedet for å bygge én stor verdi.
    private static func ibanCheckDigits(forBBAN bban: String) -> String? {
        // "N" = 23, "O" = 24 — fast for norske IBAN.
        let rearranged = "\(bban)232400"
        var remainder = 0
        for ch in rearranged {
            guard let d = Int(String(ch)) else { return nil }
            remainder = (remainder * 10 + d) % 97
        }
        let check = 98 - remainder
        return String(format: "%02d", check)
    }
}
