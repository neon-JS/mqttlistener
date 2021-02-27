import Foundation
import Network

func main()
{
    do {
        let configProvider = ConfigProvider()
        let config = try configProvider.provideConfig()

        DebugService.debugLogsActive = config.debug

        let host: NWEndpoint.Host = NWEndpoint.Host(config.host)
        let port: NWEndpoint.Port = NWEndpoint.Port(rawValue: UInt16(config.port))!
        let networkClient = NetworkClient(host: host, port: port)

        let clientId = MqttClient.generateClientId()
        let mqttClient = MqttClient(client: networkClient, clientId: clientId, userName: config.userName, password: config.password)
        mqttClient.setOnMessageHandler { (topic, data) in
            let dataString = String(data.map { (byte) -> Character in
                Character(UnicodeScalar(byte) ?? "?" as Unicode.Scalar)
            })

            print("INFO: Received message for topic '\(topic)' with payload '\(dataString)'!")
        }

        try networkClient.connect()
        try mqttClient.connect()

        for topic in config.topics {
            try mqttClient.subscribe(topic: topic)
        }

        dispatchMain()
    } catch {
        print("Error \(error)")
    }
}

main()
