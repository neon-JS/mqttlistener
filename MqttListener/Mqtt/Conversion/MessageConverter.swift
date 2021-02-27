import Foundation

class MessageConverter
{
    private let integerEncoder: IntegerEncoder

    public init(_ integerEncoder: IntegerEncoder)
    {
        self.integerEncoder = integerEncoder
    }

    public func convertToData(controlPacketType: Int, messageParts: [MessageData]) throws -> Data
    {
        let dataLength = messageParts.reduce(0) { (count, current) -> Int in count + current.count }

        var convertedData = messageParts
        convertedData.insert([ controlPacketType ], at: 0)
        convertedData.insert(try self.integerEncoder.encode(dataLength), at: 1)

        let combinedData = convertedData
            .reduce([]) { (list, current) -> [Int] in list + current }
            .map { (v) -> UInt8 in UInt8(v) }

        return combinedData.withUnsafeBytes { Data($0) }
    }

    public func extractMessages(_ data: MessageData) throws -> [MessageData]
    {
        if (data.count <= 1) {
            throw MqttFormatError.invalidMessageData
        }

        let part = Array(data[1...])
        let firstMessageEndIndex = try self.integerEncoder.getEncodedLength(part) + self.integerEncoder.decode(part)
        if (data.count <= firstMessageEndIndex) {
            throw MqttFormatError.invalidMessageData
        }

        let firstMessage = Array(data[0...firstMessageEndIndex])
        var messages = [firstMessage]

        // Check for more messages
        let nextMessageStartIndex = firstMessageEndIndex + 1
        if (data.count > nextMessageStartIndex) {
            messages += try self.extractMessages(Array(data[nextMessageStartIndex...]))
        }

        return messages
    }

    public func extractMessages(_ data: Data) throws -> [MessageData]
    {
        return try self.extractMessages(data.map { (value) -> Int in Int(value) })
    }
}
