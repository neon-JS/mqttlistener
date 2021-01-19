import Foundation
import Network;

protocol Client {
    func connect() throws
    func disconnect() throws
    func send(data: Data) throws
    func setMessageHandler(handler: ((Data) -> Void)?)
    func setOnDisconnectHandler(handler: ((NWConnection.State, NWError?) -> Void)?)
}
