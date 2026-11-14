//  Redactor.swift
//  Local redaction before text leaves the Mac for a cloud model (feature #73).
//
//  `Redactor.redact` is a pure, deterministic function: the same input always gives
//  the same output, so redacted system prompts keep their prompt-cache prefix. The
//  patterns are compiled once. Rules run from the most specific identifier to the
//  broadest (e-mail, IBAN, SSN, card, codes, account numbers, phones, long numbers),
//  so a broad rule never sees digits a specific rule already replaced. Placeholders
//  contain no digits, so they are never matched again.

import Foundation

enum Redactor {
    /// Replaces e-mail addresses, phone numbers, payment-card numbers (Luhn-checked), IBAN/account-like
    /// numbers, US SSNs and one-time codes with placeholders such as "[email]", "[phone]", "[card]".
    static func redact(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let hasDigits = text.rangeOfCharacter(from: .decimalDigits) != nil
        var result = text
        for entry in rules where hasDigits || !entry.needsDigits {
            result = entry.apply(to: result)
        }
        return result
    }

    // MARK: Placeholders

    private static let emailPlaceholder = "[email]"
    private static let ibanPlaceholder = "[iban]"
    private static let ssnPlaceholder = "[ssn]"
    private static let cardPlaceholder = "[card]"
    private static let codePlaceholder = "[code]"
    private static let phonePlaceholder = "[phone]"
    private static let numberPlaceholder = "[number]"

    // MARK: Rules

    private static let rules: [RedactionRule] = makeRules()

    /// Every repetition is bounded and every start is anchored by a look-behind, so each rule runs
    /// in linear time even on adversarial input.
    private static func makeRules() -> [RedactionRule] {
        var list: [RedactionRule?] = []

        // E-mail addresses as written ("priya.k@example.com", "sam @ mail.co.uk").
        list.append(rule("email", #"(?<![A-Z0-9._%+\-])[A-Z0-9._%+\-]{1,64} ?@ ?[A-Z0-9\-]{1,63}(?:\.[A-Z0-9\-]{1,63}){0,8}\.[A-Z]{2,24}\b"#,
                         needsDigits: false) { _, _ in Redactor.emailPlaceholder })

        // E-mail addresses as a speech recogniser writes them ("john dot smith at gmail dot com").
        // Limited to common mail providers so "look at google dot com" stays intact.
        list.append(rule("spoken email",
                         #"(?<![A-Z0-9._%+\-])[A-Z0-9][A-Z0-9._%+\-]{0,63}(?:\s+(?:dot|underscore|dash|hyphen)\s+[A-Z0-9]{1,32}){0,4}\s+at\s+(?:gmail|googlemail|yahoo|ymail|outlook|hotmail|live|msn|icloud|me|mac|aol|proton|protonmail|pm|gmx|fastmail|hey|zoho|yandex|comcast|verizon)(?:\s+dot\s+|\s?\.\s?)(?:co(?:\s+dot\s+|\.)uk|com|net|org|me|de|fr|it|es|nl|ca|io|co)\b"#,
                         needsDigits: false) { _, _ in Redactor.emailPlaceholder })

        // IBANs ("DE89 3704 0044 0532 0130 00"), checked with the ISO 13616 mod-97 checksum.
        list.append(rule("iban", #"\b[A-Z]{2}[0-9]{2}(?:[ \-]?[A-Z0-9]{4}){2,7}(?:[ \-]?[A-Z0-9]{1,3})?\b"#) { match, source in
            Redactor.redactIBAN(source.substring(with: match.range))
        })

        // US Social Security numbers written ###-##-####.
        list.append(rule("ssn", #"(?<![\d\-])\d{3}-\d{2}-\d{4}(?![\d\-])"#) { _, _ in Redactor.ssnPlaceholder })

        // Social Security numbers introduced by a keyword ("my social is 123 45 6789").
        list.append(rule("ssn keyword",
                         #"\b(ssn|social security(?: number)?|social)\b([^\d\n.!?;]{0,20}?)(\d{3}[ \-]?\d{2}[ \-]?\d{4})(?![ \-]?\d)"#) { match, source in
            Redactor.group(match, 1, source) + Redactor.group(match, 2, source) + Redactor.ssnPlaceholder
        })

        // Payment cards: 13-19 digits, contiguous or in blocks, that pass the Luhn check.
        list.append(rule("card", #"(?<!\d)\d(?:[ \-]?\d){12,18}(?!\d)"#) { match, source in
            Redactor.redactCard(source.substring(with: match.range))
        })

        // One-time codes, PINs and card security codes introduced by a keyword
        // ("your code is 482 913", "PIN 4821", "CVV 123"). The keyword is kept.
        list.append(rule("code",
                         #"\b(security code|cvv2?|cvc2?|csc|codes?|pins?|pass ?codes?|passwords?|verification|otp)\b([^\d\n.!?;]{0,20}?)((?:\d[ \-]?){2,7}\d)(?![ \-]?\d)"#) { match, source in
            let keyword = Redactor.group(match, 1, source)
            let number = Redactor.group(match, 3, source)
            guard Redactor.digitCount(number) >= Redactor.minimumCodeDigits(keyword),
                  !Redactor.isDateOrNumberList(number) else { return nil }
            return keyword + Redactor.group(match, 2, source) + Redactor.codePlaceholder
        })

        // Account-like numbers introduced by a keyword ("account number 12345678").
        list.append(rule("account keyword",
                         #"\b(account|acct|routing|policy|membership)\b((?:\s*(?:number|no\.?|num|#))?[^\d\n.!?;]{0,16}?)((?:\d[ \-]?){5,24}\d)(?![ \-]?\d)"#) { match, source in
            guard !Redactor.isDateOrNumberList(Redactor.group(match, 3, source)) else { return nil }
            return Redactor.group(match, 1, source) + Redactor.group(match, 2, source) + Redactor.numberPlaceholder
        })

        // International phone numbers ("+44 20 7946 0958", "+1 (415) 555-1234", "plus 49 30 1234567").
        list.append(rule("international phone",
                         #"(?:(?<![\w+])\+|\bplus\s)\s?\(?\d{1,4}\)?(?:[ .\-]?\(?\d{1,5}\)?){1,6}(?!\d)"#) { match, source in
            Redactor.isInternationalPhone(source.substring(with: match.range)) ? Redactor.phonePlaceholder : nil
        })

        // National and US phone numbers: 7+ digits in groups ("(415) 555-1234", "1-800-555-1234",
        // "555-1234", "020 7946 0958", "01 23 45 67 89"). Times (3:42), dates, years, decimals and
        // ranges of round numbers are rejected by `isLikelyPhone`.
        list.append(rule("phone",
                         #"(?<![\w.,:/\-+])(?:\(\d{1,5}\) ?|\d{1,5}[ .\-])(?:\d{2,8}[ .\-]|\(\d{2,5}\) ?){0,4}\d{2,8}(?!\w|[.,:/\-]\d)"#) { match, source in
            Redactor.isLikelyPhone(source.substring(with: match.range)) ? Redactor.phonePlaceholder : nil
        })

        // Long account-like numbers: 10+ contiguous digits.
        list.append(rule("long number", #"(?<!\d)\d{10,}(?!\d)"#) { _, _ in Redactor.numberPlaceholder })

        // Long account-like numbers written in blocks ("1234 5678 9012 3456 7890").
        list.append(rule("long grouped number", #"(?<![\d.,])\d{3,6}(?:[ \-]\d{3,6}){2,}(?!\d|[.,]\d)"#) { match, source in
            Redactor.isLongNumber(source.substring(with: match.range)) ? Redactor.numberPlaceholder : nil
        })

        return list.compactMap { $0 }
    }

    private static func rule(_ name: String, _ pattern: String, needsDigits: Bool = true,
                             _ transform: @escaping (NSTextCheckingResult, NSString) -> String?) -> RedactionRule? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return RedactionRule(regex: regex, needsDigits: needsDigits, transform: transform)
        } catch {
            Log.error("Redactor: invalid pattern for \(name): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: Match helpers

    /// Text of capture group `index` ("" when it did not participate).
    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ source: NSString) -> String {
        guard index < match.numberOfRanges else { return "" }
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return "" }
        return source.substring(with: range)
    }

    /// Value of a decimal digit character (ASCII or any other script), nil otherwise.
    private static func digitValue(_ character: Character) -> Int? {
        guard character.isNumber, let value = character.wholeNumberValue, (0...9).contains(value) else { return nil }
        return value
    }

    /// Maximal runs of digits with their positions ("(415) 555-1234" → 415, 555, 1234).
    private static func digitRuns(_ text: String) -> [RedactionDigitRun] {
        var runs: [RedactionDigitRun] = []
        var start: String.Index?
        var digits: [Int] = []
        var index = text.startIndex
        while index < text.endIndex {
            if let value = digitValue(text[index]) {
                if start == nil { start = index }
                digits.append(value)
            } else if let runStart = start {
                runs.append(RedactionDigitRun(range: runStart..<index, digits: digits))
                start = nil
                digits = []
            }
            index = text.index(after: index)
        }
        if let runStart = start {
            runs.append(RedactionDigitRun(range: runStart..<text.endIndex, digits: digits))
        }
        return runs
    }

    private static func digitCount(_ text: String) -> Int {
        text.reduce(0) { $0 + (digitValue($1) == nil ? 0 : 1) }
    }

    /// The number formed by (at most the first 9) digits.
    private static func numberValue(_ digits: [Int]) -> Int {
        digits.prefix(9).reduce(0) { $0 * 10 + $1 }
    }

    // MARK: Codes

    /// Card security codes have 3 digits, PINs 4+, one-time codes 6-8.
    private static func minimumCodeDigits(_ keyword: String) -> Int {
        let key = keyword.lowercased().replacingOccurrences(of: " ", with: "")
        if ["securitycode", "cvv", "cvv2", "cvc", "cvc2", "csc"].contains(key) { return 3 }
        if ["pin", "pins", "passcode", "passcodes", "password", "passwords"].contains(key) { return 4 }
        return 6
    }

    // MARK: Cards

    private static func passesLuhn(_ digits: [Int]) -> Bool {
        guard !digits.isEmpty else { return false }
        var sum = 0
        for (offset, digit) in digits.reversed().enumerated() {
            if offset % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    /// Replaces the Luhn-valid 13-19 digit card number inside `candidate` (which may also hold a
    /// neighbouring number, e.g. "room 12 4111 1111 1111 1111"); nil when there is none.
    private static func redactCard(_ candidate: String) -> String? {
        let runs = digitRuns(candidate)
        for start in runs.indices {
            var digits: [Int] = []
            var best: Int?
            for end in start..<runs.count {
                // Card numbers are spoken contiguously or in blocks of 3+ digits, never "1 2 3 4…".
                if end > start && runs[end - 1].digits.count < 3 { break }
                digits += runs[end].digits
                if digits.count > 19 { break }
                if digits.count >= 13 && passesLuhn(digits) { best = end }
            }
            if let end = best {
                let prefix = String(candidate[candidate.startIndex..<runs[start].range.lowerBound])
                let suffix = String(candidate[runs[end].range.upperBound...])
                return prefix + cardPlaceholder + suffix
            }
        }
        return nil
    }

    // MARK: IBANs

    /// Validates the candidate, then shorter prefixes ending at a separator (the pattern may have
    /// absorbed a following four-letter word).
    private static func redactIBAN(_ candidate: String) -> String? {
        var end = candidate.endIndex
        while true {
            let head = candidate[candidate.startIndex..<end]
            if isValidIBAN(String(head)) {
                return ibanPlaceholder + String(candidate[end...])
            }
            guard let separator = head.lastIndex(where: { $0 == " " || $0 == "-" }) else { return nil }
            end = separator
        }
    }

    private static func isValidIBAN(_ candidate: String) -> Bool {
        let scalars = Array(candidate.uppercased().unicodeScalars.filter { $0 != " " && $0 != "-" })
        guard (15...34).contains(scalars.count) else { return false }
        func isLetter(_ s: Unicode.Scalar) -> Bool { s.value >= 65 && s.value <= 90 }
        func isDigit(_ s: Unicode.Scalar) -> Bool { s.value >= 48 && s.value <= 57 }
        guard isLetter(scalars[0]), isLetter(scalars[1]), isDigit(scalars[2]), isDigit(scalars[3]) else { return false }
        var remainder = 0
        for scalar in Array(scalars[4...]) + Array(scalars[..<4]) {
            if isDigit(scalar) {
                remainder = (remainder * 10 + Int(scalar.value - 48)) % 97
            } else if isLetter(scalar) {
                remainder = (remainder * 100 + Int(scalar.value - 55)) % 97
            } else {
                return false
            }
        }
        return remainder == 1
    }

    // MARK: Phones and long numbers

    private static func isYear(_ digits: [Int]) -> Bool {
        digits.count == 4 && (1900...2099).contains(numberValue(digits))
    }

    private static func isDayOrMonth(_ digits: [Int]) -> Bool {
        digits.count <= 2 && (1...31).contains(numberValue(digits))
    }

    /// "2026-11-14", "14.11.2026", "11 14 2026".
    private static func looksLikeDate(_ groups: [[Int]]) -> Bool {
        guard groups.count == 3 else { return false }
        if isYear(groups[0]) && isDayOrMonth(groups[1]) && isDayOrMonth(groups[2]) { return true }
        return isDayOrMonth(groups[0]) && isDayOrMonth(groups[1]) && isYear(groups[2])
    }

    /// Years ("2019 2020", "2024-2025") or round quantities and ranges ("500-1000", "100 200 300").
    private static func isPlainNumberList(_ groups: [[Int]]) -> Bool {
        if groups.allSatisfy({ Redactor.isYear($0) }) { return true }
        return groups.allSatisfy { $0.last == 0 }
    }

    /// A keyword followed by a date ("code review on 10 30 2026") or by years / round numbers.
    private static func isDateOrNumberList(_ text: String) -> Bool {
        let groups = digitRuns(text).map { $0.digits }
        return looksLikeDate(groups) || (groups.count >= 2 && isPlainNumberList(groups))
    }

    private static func isInternationalPhone(_ candidate: String) -> Bool {
        let count = digitCount(candidate)
        let minimum = candidate.hasPrefix("+") ? 8 : 10   // "plus …" needs more evidence than "+"
        return count >= minimum && count <= 15
    }

    private static func isLikelyPhone(_ candidate: String) -> Bool {
        let groups = digitRuns(candidate).map { $0.digits }
        let count = groups.reduce(0) { $0 + $1.count }
        guard groups.count >= 2, count >= 7, count <= 15 else { return false }
        if looksLikeDate(groups) || isPlainNumberList(groups) { return false }
        let separators = Set(candidate.filter { $0 == " " || $0 == "." || $0 == "-" })
        if separators.contains(".") && (groups.count == 2 || separators.count > 1) {
            // "1234.5678" (a decimal) or "10.30-11.45" (a time range); "01.23.45.67.89" stays a phone.
            return false
        }
        return true
    }

    private static func isLongNumber(_ candidate: String) -> Bool {
        let groups = digitRuns(candidate).map { $0.digits }
        let count = groups.reduce(0) { $0 + $1.count }
        return count >= 10 && !isPlainNumberList(groups)
    }
}

// MARK: - Private types

/// One compiled pattern and how to rewrite its matches.
private struct RedactionRule {
    let regex: NSRegularExpression
    /// False for rules that can match text without digits (e-mail addresses).
    let needsDigits: Bool
    /// The replacement for one match, or nil to keep the matched text unchanged.
    let transform: (NSTextCheckingResult, NSString) -> String?

    func apply(to text: String) -> String {
        let source = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }
        var output = ""
        var cursor = 0
        var changed = false
        for match in matches {
            let range = match.range
            guard range.location != NSNotFound, range.length > 0, range.location >= cursor,
                  let replacement = transform(match, source) else { continue }
            output += source.substring(with: NSRange(location: cursor, length: range.location - cursor))
            output += replacement
            cursor = range.location + range.length
            changed = true
        }
        guard changed else { return text }
        output += source.substring(from: cursor)
        return output
    }
}

/// A maximal run of digits inside a matched candidate.
private struct RedactionDigitRun {
    let range: Range<String.Index>
    let digits: [Int]
}
