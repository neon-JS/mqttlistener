import Foundation

class StringEncoder : Encoder
{
    typealias T = String

    public func decode(_ data: MessageData) throws -> String
    {
        if (data.count < 2) {
            throw MqttFormatError.invalidStringData
        }

        let lastStringDataIndex = (data[0] << 8) + data[1] + 1 // Offset = 2, but remove 1 because of zero-indexing
        if (data.count <= lastStringDataIndex) {
            throw MqttFormatError.invalidStringData
        }

        let chars = data[2...lastStringDataIndex].map { (byte) -> Character in
            Character(UnicodeScalar(byte)!)
        }

        return String(chars)
    }

    public func encode(_ value: String) throws -> MessageData
    {
        let utf8string = value.utf8
        var bytes: MessageData = []

        if (utf8string.count > Mqtt.Utf8StringMaxByteSize) {
            throw MqttFormatError.stringMaxLengthExceeded
        }

        bytes.append(utf8string.count >> 8) // Length MSB
        bytes.append(utf8string.count & 0b1111_1111) // Length LSB

        for char in utf8string {
            if (char == 0x00) {
                throw MqttFormatError.invalidStringData
            }

            bytes.append(Int(char))
        }

        return bytes
    }

    public func getEncodedLength(_ data: MessageData) throws -> Int
    {
        if (data.count < 2) {
            throw MqttFormatError.invalidStringData
        }

        return (data[0] << 8) + data[1] + 2
    }
}
