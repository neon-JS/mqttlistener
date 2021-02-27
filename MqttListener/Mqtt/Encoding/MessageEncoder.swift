import Foundation

typealias Message = [Int]
typealias MessageData = [Int]

class MessageEncoder
{
    public static func encodeMessageFromParts(controlPacketType: Int, _ data: [MessageData]) throws -> Data
    {
        let dataLength = data.reduce(0) { (count, current) -> Int in count + current.count }

        var convertedData = data
        convertedData.insert([ controlPacketType ], at: 0)
        convertedData.insert(try IntegerEncoder.encodeVariableByteInteger(dataLength), at: 1)

        let combinedData = convertedData
            .reduce([]) { (list, current) -> [Int] in list + current }
            .map { (v) -> UInt8 in UInt8(v) }

        return combinedData.withUnsafeBytes { Data($0) }
    }

    public static func extractMessagesFromData(_ data: MessageData) throws -> [Message]
    {
        if (data.count <= 1) {
            throw MqttFormatError.invalidMessageData
        }

        let firstMessageEndIndex = try MessageEncoder.getEncodedIntegerLength(data[1...]) + IntegerEncoder.decodeVariableByteInteger(Array(data[1...]));
        if (data.count <= firstMessageEndIndex) {
            throw MqttFormatError.invalidMessageData
        }

        let firstMessage = Array(data[0...firstMessageEndIndex])
        var messages = [firstMessage]

        // Check for more messages
        let nextMessageStartIndex = firstMessageEndIndex + 1;
        if (data.count > nextMessageStartIndex) {
            messages += try self.extractMessagesFromData(Array(data[nextMessageStartIndex...]))
        }

        return messages
    }

    public static func getFirstDataByteIndex(_ data: Message) throws -> Int
    {
        return try MessageEncoder.getEncodedIntegerLength(data[1...]) + 1
    }

    public static func getEncodedIntegerLength(_ data: ArraySlice<Int>) throws -> Int
    {
        for (index, byte) in data.enumerated() {
            if (byte & Mqtt.VariableByteIntegerContinuationBit == 0) {
                return index + 1;
            }
        }

        throw MqttFormatError.invalidVariableIntegerData
    }
}
