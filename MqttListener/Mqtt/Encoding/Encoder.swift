import Foundation

protocol Encoder
{
    associatedtype T

    func encode(_ value: T) throws -> MessageData
    func decode(_ data: MessageData) throws -> T
    func getEncodedLength(_ data: MessageData) throws -> Int
}
