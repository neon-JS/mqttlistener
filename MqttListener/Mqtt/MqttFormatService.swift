import Foundation

class MqttFormatService
{
    public static func encodeVariableByteInteger(_ value: Int) throws -> [Int]
    {
        if (value > Mqtt.VariableIntegerMaxSize) {
            throw MqttFormatError.variableIntegerOverflow
        }

        var bytes: [Int] = []
        var handledValue = value

        while handledValue > 0 {
            var leastSignificantByte = handledValue % Mqtt.VariableByteIntegerContinuationBit   // Get LSB (aka "the next seven bits")
            handledValue = handledValue >> 7                                                    // Remove LSB from value

            if (handledValue > 0) {
                // For every byte that is not the last one (because there's a value left)
                leastSignificantByte = leastSignificantByte | Mqtt.VariableByteIntegerContinuationBit
            }

            bytes.append(leastSignificantByte)
        }

        return bytes
    }

    public static func decodeVariableByteInteger(_ values: [Int]) throws -> Int
    {
        if (values.count > 4) {
            throw MqttFormatError.variableIntegerOverflow
        }

        var multiplier = 1
        var value = 0

        for byte in values {
            value += (byte & Mqtt.VariableByteIntegerValueBits) * multiplier
            multiplier *= 0b1000_0000
        }

        return value
    }

    public static func encodeString(_ value: String) throws -> [Int]
    {
        let utf8string = value.utf8
        var bytes: [Int] = []

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
    
    public static func decodeString(_ bytes: [Int]) -> String
    {
        let chars = bytes[2..<bytes.count].map { (byte) -> Character in
            Character(UnicodeScalar(byte) ?? "?" as Unicode.Scalar)
        }

        return String(chars)
    }

    public static func dataToIntArray(_ data: Data) -> [Int]
    {
        return data.map { (value) -> Int in
            Int(value)
        }
    }

    public static func convertMessageToData(controlPacketType: Int, data: [[Int]]) throws -> Data
    {
        let dataLength = data.reduce(0) { (count, current) -> Int in count + current.count }

        var convertedData = data
        convertedData.insert([ controlPacketType ], at: 0)
        convertedData.insert(try self.encodeVariableByteInteger(dataLength), at: 1)

        let combinedData = convertedData
            .reduce([]) { (list, current) -> [Int] in list + current }
            .map { (v) -> UInt8 in UInt8(v) }

        return combinedData.withUnsafeBytes { Data($0) }
    }

    public static func extractMessagesFromData(data: [Int]) throws -> [[Int]]
    {
        var remainingLengthEndIndex = 1
        while data[remainingLengthEndIndex] & Mqtt.VariableByteIntegerContinuationBit == Mqtt.VariableByteIntegerContinuationBit {
            remainingLengthEndIndex += 1
        }

        let lastByteIndex = try self.decodeVariableByteInteger(Array(data[1...remainingLengthEndIndex])) + remainingLengthEndIndex
        let currentMessage = Array(data[0..<lastByteIndex + 1])
        var messages = [currentMessage]

        if (lastByteIndex + 1 < data.count) {
            messages += try self.extractMessagesFromData(data: Array(data[lastByteIndex + 1..<data.count]))
        }

        return messages
    }

    public static func generateClientId() -> String
    {
        var clientId = "MqttListener"

        for _ in clientId.count..<Mqtt.ClientIdMaxLength {
            clientId.append(Mqtt.ClientIdValidChars.randomElement()!)
        }

        return clientId
    }
}
