//
//  ServerLocator.swift
//  Emby.ApiClient
//
//  Created by Vedran Ozir on 03/11/15.
//  Copyright © 2015 Vedran Ozir. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

public class ServerLocator: ServerDiscoveryProtocol, GCDAsyncUdpSocketDelegate {
    
    private let logger: ILogger
    private let jsonSerializer: IJsonSerializer
    
    private var onSuccess: (([ServerDiscoveryInfo]) -> Void)?
    var serverDiscoveryInfo: Set<ServerDiscoveryInfo> = []
    
    public init( logger: ILogger, jsonSerializer: IJsonSerializer) {
        self.logger = logger;
        self.jsonSerializer = jsonSerializer;
    }
    
    
    // MARK: - utility methods
    
    public func findServers(timeoutMs: Int, onSuccess: ([ServerDiscoveryInfo]) -> Void, onError: (ErrorType) -> Void)
    {
        let udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        
        // Find the server using UDP broadcast
        
        do {
            self.onSuccess = onSuccess
            
            try udpSocket.enableBroadcast(true)
            
            let sendData = "who is EmbyServer?".dataUsingEncoding(NSUTF8StringEncoding);
            let host = "255.255.255.255"
            let port: UInt16 = 7359;
            
            udpSocket.sendData(sendData, toHost: host, port: port, withTimeout: NSTimeInterval(Double(timeoutMs)/1000.0), tag: 1)
            
            print("ServerLocator >>> Request packet sent to: 255.255.255.255 (DEFAULT)");
            
        } catch {
            print("Error sending DatagramPacket \(error)")
            
            onError(error)
        }
    }
    
    @objc func finished() {
        
        print("Found \(serverDiscoveryInfo.count) servers");
        
        self.onSuccess?(Array(serverDiscoveryInfo))
    }
    
    private func Receive(c: GCDAsyncUdpSocket, timeoutMs: UInt, onResponse: ([ServerDiscoveryInfo]) -> Void) throws {
        
        serverDiscoveryInfo = []
        let timeout = NSTimeInterval(Double(timeoutMs) / 1000.0)
        
        NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: Selector("finished"), userInfo: nil, repeats: false)
        
        do {
            try c.beginReceiving()
        }
        catch {
            print (error)
        }
    }
    
    
    // MARK: - GCDAsyncUdpSocketDelegate
    
    /**
    * By design, UDP is a connectionless protocol, and connecting is not needed.
    * However, you may optionally choose to connect to a particular host for reasons
    * outlined in the documentation for the various connect methods listed above.
    *
    * This method is called if one of the connect methods are invoked, and the connection is successful.
    **/
    @objc public func udpSocket(sock: GCDAsyncUdpSocket!, didConnectToAddress address: NSData!) {
        
        print("didConnectToAddress")
    }
    
    
    /**
     * By design, UDP is a connectionless protocol, and connecting is not needed.
     * However, you may optionally choose to connect to a particular host for reasons
     * outlined in the documentation for the various connect methods listed above.
     *
     * This method is called if one of the connect methods are invoked, and the connection fails.
     * This may happen, for example, if a domain name is given for the host and the domain name is unable to be resolved.
     **/
    @objc public func udpSocket(sock: GCDAsyncUdpSocket!, didNotConnect error: NSError!) {
        
        print("didNotConnect")
    }
    
    
    /**
     * Called when the datagram with the given tag has been sent.
     **/
    @objc public func udpSocket(sock: GCDAsyncUdpSocket!, didSendDataWithTag tag: Int) {
        
        print("didSendDataWithTag")
        do {
            try self.Receive(sock, timeoutMs: UInt(1000), onResponse: { (serverDiscoveryInfo: [ServerDiscoveryInfo]) -> Void in
                
                print("serverDiscoveryInfo \(serverDiscoveryInfo)")
            })
        } catch {
            print("\(error)")
        }
    }
    
    
    /**
     * Called if an error occurs while trying to send a datagram.
     * This could be due to a timeout, or something more serious such as the data being too large to fit in a sigle packet.
     **/
    @objc public func udpSocket(sock: GCDAsyncUdpSocket!, didNotSendDataWithTag tag: Int, dueToError error: NSError!) {
        
        print("didNotSendDataWithTag")
    }
    
    
    /**
     * Called when the socket has received the requested datagram.
     **/
    @objc public func udpSocket(sock: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress address: NSData!, withFilterContext filterContext: AnyObject!) {
        
        let json = NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        
        // We have a response
        print("ServerLocator >>> Broadcast response from server: \(sock.localAddress()): \(json)")
        
        do {
            if let serverInfo: ServerDiscoveryInfo = try JsonSerializer().DeserializeFromString( json!, type:nil) {
                
                self.serverDiscoveryInfo.insert(serverInfo)
            }
        } catch {
            print("\(error)")
        }
    }
    
    
    /**
     * Called when the socket is closed.
     **/
    @objc public func udpSocketDidClose(sock: GCDAsyncUdpSocket!, withError error: NSError!) {
        
        print("udpSocketDidClose")
    }
}