import Foundation

/// Validerer norske personnumre og utleder fødselsdato fra dem.
/// Regler følger Skatteetaten: 11 siffer (DDMMYY-III-KK), MOD-11 sjekksum
/// på begge kontrollsifrene, og århundre utledet fra individnummeret.
///
/// D-nummer (utlendinger med norsk ID — første siffer +4) støttes ikke
/// i v1; vi forventer at utleiere bruker fødselsnummer. H-nummer
/// (helsepersonell — andre siffer +4) avvises også.
enum PersonnummerHelper {

    struct DateOfBirth: Equatable {
        let day: Int
        let month: Int
        let year: Int
    }

    /// Returnerer fødselsdato hvis personnummeret er gyldig, ellers nil.
    /// Validerer både MOD-11-sjekksifrene og at DDMMYY er en reell dato.
    static func dateOfBirth(from pnr: String) -> DateOfBirth? {
        let digits = pnr.filter(\.isNumber)
        guard digits.count == 11 else { return nil }
        let chars = Array(digits)

        let dd = Int(String(chars[0...1])) ?? -1
        let mm = Int(String(chars[2...3])) ?? -1
        let yy = Int(String(chars[4...5])) ?? -1
        let iii = Int(String(chars[6...8])) ?? -1
        guard dd > 0, mm > 0, yy >= 0, iii >= 0 else { return nil }

        // D-nummer (DD+40) og H-nummer (MM+40) ikke støttet i v1.
        if dd > 31 || mm > 12 { return nil }

        guard let year = year(from: yy, individnummer: iii) else { return nil }

        // Verifiser at datoen faktisk eksisterer (skuddår, måneds-lengde osv).
        var comps = DateComponents()
        comps.day = dd
        comps.month = mm
        comps.year = year
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        guard let date = cal.date(from: comps),
              let resolved = cal.dateComponents([.day, .month, .year], from: date) as DateComponents?,
              resolved.day == dd, resolved.month == mm, resolved.year == year else {
            return nil
        }

        // MOD-11 sjekksifre — fanger skrivefeil før vi sender til Stripe.
        guard isChecksumValid(chars: chars) else { return nil }

        return DateOfBirth(day: dd, month: mm, year: year)
    }

    // MARK: - Internt

    /// Århundre-regelen for individnummeret (Skatteetaten):
    /// - 000–499 → 1900-tallet
    /// - 500–749 og YY 54–99 → 1800-tallet (1854–1899)
    /// - 500–999 og YY 00–39 → 2000-tallet (2000–2039)
    /// - 900–999 og YY 40–99 → 1900-tallet (1940–1999)
    private static func year(from yy: Int, individnummer iii: Int) -> Int? {
        if iii <= 499 { return 1900 + yy }
        if iii >= 500, iii <= 749, yy >= 54 { return 1800 + yy }
        if iii >= 500, iii <= 999, yy <= 39 { return 2000 + yy }
        if iii >= 900, iii <= 999, yy >= 40 { return 1900 + yy }
        return nil
    }

    /// MOD-11 med vektene Skatteetaten bruker for K1 og K2.
    /// Resultatet er ugyldig hvis enten kontrollsifferet blir 10 (umulig)
    /// eller hvis det utregnete sifferet ikke matcher det oppgitte.
    private static func isChecksumValid(chars: [Character]) -> Bool {
        let digits = chars.compactMap { Int(String($0)) }
        guard digits.count == 11 else { return false }

        let w1 = [3, 7, 6, 1, 8, 9, 4, 5, 2]
        let w2 = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]

        let sum1 = zip(digits.prefix(9), w1).reduce(0) { $0 + $1.0 * $1.1 }
        var k1 = 11 - (sum1 % 11)
        if k1 == 11 { k1 = 0 }
        if k1 == 10 { return false }
        if k1 != digits[9] { return false }

        let sum2 = zip(digits.prefix(10), w2).reduce(0) { $0 + $1.0 * $1.1 }
        var k2 = 11 - (sum2 % 11)
        if k2 == 11 { k2 = 0 }
        if k2 == 10 { return false }
        return k2 == digits[10]
    }
}
