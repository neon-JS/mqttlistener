import Foundation

protocol MessagePartParser
{
    associatedtype T

    func extractPart(messageData: MessageData, offset: Int) throws -> (T, Int)
}
