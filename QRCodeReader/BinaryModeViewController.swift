//
//  BinaryModeViewController.swift
//  QRCodeReader
//
//  Created by Takaki Yoneyama on 2018/09/01.
//  Copyright © 2018年 Takaki Yoneyama. All rights reserved.
//

import UIKit

class BinaryModeViewController: UIViewController {

    lazy var binary: Binary = { preconditionFailure() }()
    lazy var symbolVersion: Int = { preconditionFailure() }()

    @IBOutlet private weak var textView: UITextView!
    @IBOutlet private weak var decodedTextView: UITextView!

    private let supportedModes: [Mode] = [.structuredAppend, .byte, .endOfMessage]

    override func viewDidLoad() {
        super.viewDidLoad()

        showBinary()
        var workingBinary = binary
        workingBinary.readingOffset = 0
        decode(&workingBinary)
    }

    private func showBinary() {
        let bitsStrings: [String] = binary.bytes.map { (_) -> String in
            var string = ""
            for _ in 0...7 {
                string += String(binary.next(bits: 1))
            }
            return string
        }

        textView.text = bitsStrings.reduce("") {
            guard var result = $0 else { return "" }
            let bitsPair = String($1.prefix(4) + " " + $1.suffix(4))
            result += (result.isEmpty) ? bitsPair : " " + bitsPair
            return result
        }
    }

    private func decode(_ binary: inout Binary) {
        let modeBitsLength = 4
        guard binary.bitsWithInternalOffsetAvailable(modeBitsLength) else { return }

        let modeBits = binary.next(bits: modeBitsLength)
        guard let mode = Mode(rawValue: modeBits),
            supportedModes.contains(mode) else {
            showError()
            return
        }

        insertModeDecription(mode)
        guard mode != .endOfMessage else { return }

        if case .structuredAppend = mode {
            let symbolPosition = binary.next(bits: 4)
            let totalSymbols = binary.next(bits: 4)
            let parity = binary.next(bits: 8)
            append("Total: \(totalSymbols + 1), Position: \(symbolPosition + 1). Parity: \(parity).\n\n")
        } else if case .byte = mode {
            guard let numberOfBitsInLengthFiled = mode.numberOfBitsInLengthFiled(for: symbolVersion),
                let numberOfBitsPerCharacter = mode.numberOfBitsPerCharacter else { return }
            let totalCharacterCount = binary.next(bits: numberOfBitsInLengthFiled)
            var bytes: [UInt8] = []
            for _ in 0..<totalCharacterCount {
                let byte = binary.next(bits: numberOfBitsPerCharacter)
                bytes.append(UInt8(byte))
            }
            let text = String(bytes: bytes, encoding: .utf8) ?? ""
            append(text)
        }

        decode(&binary)
    }

    private func showError() {
        append("No data or the decode failed.\n")
    }

    private func insertModeDecription(_ mode: Mode) {
        append("\nモード: " + mode.description + "\n")
    }

    private func append(_ string: String) {
        decodedTextView.text = (decodedTextView.text ?? "") + string
    }

}

enum SymbolType {
    case small
    case medium
    case large

    init?(version: Int) {
        if 1 <= version, version <= 9 {
            self = .small
        } else if 10 <= version, version <= 26 {
            self = .medium
        } else if 27 <= version, version <= 40 {
            self = .large
        } else {
            return nil
        }
    }
}

enum Mode: Int {
    case numeric              = 1 // 0001 数字
    case alphanumeric         = 2 // 0010 英数字
    case byte                 = 4 // 0100 バイト
    case kanji                = 8 // 1000 漢字
    case structuredAppend     = 3 // 0011 構造的連接
    case eci                  = 7 // 0111 ECI
    case fnc1InFirstPosition  = 5 // 0101 FNC1（1番目の位置）
    case fnc1InSecondPosition = 9 // 1001 FNC1（1番目の位置）
    case endOfMessage         = 0 // 0000 終端パターン

    var description: String {
        switch self {
        case .numeric:              return "0001 数字"
        case .alphanumeric:         return "0010 英数字"
        case .byte:                 return "0100 バイト"
        case .kanji:                return "1000 漢字"
        case .structuredAppend:     return "0011 構造的連接"
        case .eci:                  return "0111 ECI"
        case .fnc1InFirstPosition:  return "0101 FNC1（1番目の位置）"
        case .fnc1InSecondPosition: return "1001 FNC1（1番目の位置）"
        case .endOfMessage:         return "0000 終端パターン"
        }
    }

    var hasNumberOfBitsInLengthFiled: Bool {
        switch self {
        case .numeric, .alphanumeric, .byte, .kanji:
            return true
        default:
            return false
        }
    }

    var numberOfBitsPerCharacter: Int? {
        switch self {
        case .numeric: return 10
        case .alphanumeric: return 11
        case .byte: return 8
        case .kanji: return 13
        default: return nil
        }
    }

    func numberOfBitsInLengthFiled(for symbolVersion: Int) -> Int? {
        guard let symbolType = SymbolType(version: symbolVersion) else { return nil }
        switch self {
        case .numeric:
            switch symbolType {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }

        case .alphanumeric:
            switch symbolType {
            case .small: return 9
            case .medium: return 11
            case .large: return 13
            }

        case .byte:
            switch symbolType {
            case .small: return 8
            case .medium: return 16
            case .large: return 16
            }

        case .kanji:
            switch symbolType {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }

        default:
            return nil
        }
    }
}
