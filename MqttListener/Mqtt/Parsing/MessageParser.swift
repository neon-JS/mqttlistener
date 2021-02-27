import Foundation

protocol MessageParser
{
    func parse(message: MessageData) throws -> Message
}
