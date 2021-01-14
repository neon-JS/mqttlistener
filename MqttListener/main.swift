import Foundation
import Network

func main() {
    let c = NetworkClient(host: "", port: 1883, params: NWParameters.tcp)

    do {
        try c.connect()
        let mqtt = MqttClient(client: c, clientId: "test")
        
        mqtt.setOnMessage { (topic, data) in
            let dataString = String(data.map { (byte) -> Character in
                Character(UnicodeScalar(byte) ?? "?" as Unicode.Scalar)
            })
            
            print("INFO: Received message for topic '\(topic)' with payload '\(dataString)'!")
        }
        
        mqtt.connect()
        sleep(2)
        mqtt.subscribe(topic: "test")
    } catch {
        print("Could not connect!")
    }
    
    dispatchMain()
}

main()
