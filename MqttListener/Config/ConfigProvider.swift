import Foundation

class ConfigProvider
{
    public func provideConfig() throws -> Config
    {
        let filePath = Bundle.main.path(forResource: "config", ofType: "json")
        if (filePath == nil) {
            throw FileError.notFound
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath!))
        return try JSONDecoder().decode(Config.self, from: data)
    }
}
