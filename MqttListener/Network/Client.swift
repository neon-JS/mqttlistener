import Foundation
import Network;

protocol Client
{
    func connect() throws
    func disconnect() throws
    func send(_ data: Data) throws
    func setOnDataHandler(_ handler: ((Data) -> Void)?)
    func setOnDisconnectHandler(_ handler: ((NWConnection.State, NWError?) -> Void)?)
}
