import Foundation
import Network

class MqttClient {
    private var client : Client
    private var clientId : String
    private var onMessage: ((String, [Int]) -> Void)?

    init(client: Client, clientId: String) {
        self.client = client
        self.clientId = clientId
        self.client.setMessageHandler(handler: self.onMessage(data:))
        self.client.setOnDisconnectHandler(handler: self.onDisconnect(state:error:))
    }
    
    public func setOnMessage(handler: ((String, [Int]) -> Void)?)
    {
        self.onMessage = handler;
    }
    
    private func onMessage(data: Data) -> Void
    {
        let convertedData = MqttFormatService.dataToIntArray(data: data)
        
        if (data[0] == 0b0010_0000) {
            self.handleConnAc(data: convertedData)
        } else if ((data[0] & 0b0011_0000) == 0b0011_0000) {
            self.onPublish(data: convertedData)
        } else if (data[0] == 0b1001_0000) {
            self.onSubAck(data: convertedData)
        }
        
        else {
            print("DEBUG: Received unspecified message with \(data.count) bytes!")

            for c in data {
                print(c)
            }
        }
    }
    
    private func onSubAck(data: [Int])
    {
        print("DEBUG: Got SUBACK!")
        
        /*
            0b1001_0000 // SUBACK
            0bXXXX_XXXX // Remaining length
         
            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (MSB)
            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (LSB)
         
            0bXXXX_XXXX // Properties length
         
            0bXXXX_XXXX // Payload
         */
        
        let payloadIndex = Int(5 + data[4]);
        
        if (data[payloadIndex] >= 0b1000_0000) {
            // Payload contains status-code. Every status-code >= 128 indicates an error.
            print("ERROR: Error code during SUBACK: \(data[payloadIndex])")
        }
    }
    
    private func handleConnAc(data: [Int])
    {
        print("DEBUG: Got CONNACK!")
        /*
            0b0010_0000 // Type CONNACK
            0bXXXX_XXXX // Remaining length
                 
            0b0000_000X // CONNACK Flags. If 0b0000_0001 -> resumed session, otherwise clean session. All other bits (0b0000_000X) are reserved!
         
            0bXXXX_XXXX // Status Code ("Reason Code") -> Status
         
            0b0000_0011 // Properties length
            
            0b0001_0010 // 34 -> Topic alias maximum: Next to bytes showing max topics
            0b0000_0000 // 0 (MSB)
            0b0000_1001 // 10 (LSB)
         
         */
        
        if (data[2] != 0b0000_0000) {
            print("DEBUG: Using resumed session!");
        } else {
            print("DEBUG: Using clean session!")
        }
        
        if (data[3] != 0b0000_0000) {
            print("ERROR: Status ERROR! '\(data[3])'")
        }
    }
    
    private func onPublish(data: [Int])
    {
        print("DEBUG: Got PUBLISH!")
        /*
            0b0011_DQQR // D = is duplicate (server -> client always 0), QQ = QoS, R = retain
            0bXXXX_XXXX // Remaining length
         
            0bXXXX_XXXX // Topic Name length (MSB)
            0bXXXX_XXXX // Topic Name length (LSB)
            0bXXXX_XXXX // Topic name
            ...
         
           (0bXXXX_XXXX) // Packet identifier MSB (QoS > 0)
           (0bXXXX_XXXX) // Packet identifier LSB (QoS > 0)
         
            0bXXXX_XXXX // Properties length
                
            0bXXXX_XXXX // Data!
            ...
         
         */
        
        let topicLength = Int(data[2] << 8 + data[3]);
        
        var dataStart = topicLength + 4;
        if (data[0] & 0b0000_0110 != 0) {
            // QoS > 0
            dataStart += 2;
        }

        let topic = MqttFormatService.decodeString(bytes: Array(data[2..<topicLength + 4]))
        let payload = Array(data[dataStart..<data.count]);
        
        if (self.onMessage != nil) {
            self.onMessage!(topic, payload)
        }
    }
    
    private func onDisconnect(state: NWConnection.State, error: NWError?) -> Void
    {
     //   print("Disconnected with state '\(state)' and error '\(String(describing: error))'!")
    }
    
    public func connect()
    {
        let parts: [[Int]] = [
            [
                0b0001_0000, // first byte, identifying CONNECT-request
                0b0000_0000, // Remaining length, currently unknown! TODO
            ],
            MqttFormatService.encodeString(value: "MQTT"),
            [
                0b0000_0101, // Protocol version (5)
                
                0b0000_0010, // Properties, currently without last will / authentication to keep it simple!
                
                0b0000_0000, // Keepalive MSB,
                0b0000_0000, // Keepalive LSB
                
                0x0000_0000, // Property-length (0 as no properties are set) but necessary for MQTT5
            ],
            MqttFormatService.encodeString(value: self.clientId)
        ];
        
        try! self.client.send(data: MqttFormatService.convertToData(values: parts))
    }
    
    public func subscribe(topic: String)
    {
        let parts: [[Int]] = [
            [
                0b1000_0010, // Identifier of SUBSCRIBE
                0b0000_1010, // Remaining length, TODO
                
                0b0000_0000, // Packet identifier (MSB). We use this to recognize the ACK later. We also choose the identifier ourselves!
                0b0000_1110, // Packet identifier (LSB)
                
                0b0000_0000, // Properties length. As we dont use them, its 0
            ],
            MqttFormatService.encodeString(value: topic),
            [
                0b0000_0110, // Subscription options
            ]
        ];
        try! self.client.send(data: MqttFormatService.convertToData(values: parts))
    }
    
    public func disconnect()
    {
        let data = Data([
            0b1110_0000, // DISCONNECT
            0b0000_0000, // Remaining length
            
            0b0000_0000, // Reason code -> normal disconnection
            
            0b0000_0000, // Properties length (empty, therefore 0)
        ]);
        
        try! self.client.send(data: data)
        try! self.client.disconnect()
    }
}
