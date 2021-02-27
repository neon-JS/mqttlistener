import Foundation

struct Message
{
    public let fixedHeader: Int
    public let remainingLength: Int
    public let topicName: String?
    public let packetIdentifier: Int?
    public let properties: Properties?
    public let payload: [Int]?
    public let reasonCode: Int?
    public let connackFlags: Int?
}
