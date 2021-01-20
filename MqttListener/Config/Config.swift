import Foundation

struct Config : Codable
{
    public let host: String
    public let port: Int
    public let userName: String?
    public let password: String?
    public let topics: [String]
}
