import CryptoKit
import Foundation

// Run before publishing an appcast to catch signing with the wrong Keychain key.
guard CommandLine.arguments.count == 4,
      let key = Data(base64Encoded: CommandLine.arguments[2]),
      let signature = Data(base64Encoded: CommandLine.arguments[3]) else {
    FileHandle.standardError.write(Data("Expected archive, public key, and signature\n".utf8))
    exit(1)
}
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key)
guard publicKey.isValidSignature(signature, for: archive) else {
    FileHandle.standardError.write(Data("The update was not signed by sparklePublicKey in release.json\n".utf8))
    exit(1)
}
