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
        var remainingLengthEndIndex = 1
        while data[remainingLengthEndIndex] & Mqtt.VariableByteIntegerContinuationBit == Mqtt.VariableByteIntegerContinuationBit {
            remainingLengthEndIndex += 1
        }

        let lastByteIndex = try IntegerEncoder.decodeVariableByteInteger(Array(data[1...remainingLengthEndIndex])) + remainingLengthEndIndex
        let currentMessage = Array(data[0..<lastByteIndex + 1])
        var messages = [currentMessage]

        if (lastByteIndex + 1 < data.count) {
            messages += try self.extractMessagesFromData(Array(data[lastByteIndex + 1..<data.count]))
        }

        return messages
    }
}
