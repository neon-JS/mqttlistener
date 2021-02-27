import Foundation

class StringEncoder
{
    public static func encodeString(_ value: String) throws -> MessageData
    {
        let utf8string = value.utf8
        var bytes: MessageData = []

        if (utf8string.count > Mqtt.Utf8StringMaxByteSize) {
            throw MqttFormatError.stringMaxLengthExceeded
        }

        bytes.append(utf8string.count >> 8) // Length MSB
        bytes.append(utf8string.count & 0b1111_1111) // Length LSB

        for char in utf8string {
            bytes.append(Int(char))
        }

        return bytes
    }

    public static func decodeString(_ bytes: MessageData) -> String
    {
        let chars = bytes[2..<bytes.count].map { (byte) -> Character in
            Character(UnicodeScalar(byte)!)
        }

        return String(chars)
    }
}
