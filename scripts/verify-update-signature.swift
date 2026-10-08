import CryptoKit
import Foundation

// Public data only: never read or print the publisher's private signing key.
do {
    guard CommandLine.arguments.count == 4 else { throw VerificationError.invalidInput }
    let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]), options: .mappedIfSafe)
    let plist = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
    guard let info = try PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
          let encodedKey = info["SUPublicEDKey"] as? String,
          let keyData = Data(base64Encoded: encodedKey),
          let signature = Data(base64Encoded: CommandLine.arguments[2]) else {
        throw VerificationError.invalidInput
    }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    guard key.isValidSignature(signature, for: archive) else { throw VerificationError.signatureMismatch }
    print("Update signature matches the public key embedded in the app.")
} catch {
    fputs("Update signature verification failed. Check the archive and SPARKLE_PRIVATE_KEY.\n", stderr)
    exit(1)
}

enum VerificationError: Error { case invalidInput, signatureMismatch }
