
import PsiphonTunnel

@objc(PSICordova) class PSICordova : CDVPlugin {
  var psiphonConfig: String = "{}"
	var psiphonTunnel: PsiphonTunnel?
  var session: URLSession?
  static var socksProxyPort: Int = 0
  static var httpProxyPort: Int = 0

  var startCommand: CDVInvokedUrlCommand?

  func config(_ command: CDVInvokedUrlCommand) {
    let pluginResult = CDVPluginResult(
      status: CDVCommandStatus_OK
    )

    self.psiphonConfig = command.arguments.first as! String

    JAHPAuthenticatingHTTPProtocol.setDelegate(self)
    JAHPAuthenticatingHTTPProtocol.start()
    self.psiphonTunnel = PsiphonTunnel.newPsiphonTunnel(self)

    self.commandDelegate!.send(
        pluginResult,
        callbackId: command.callbackId
    )
  }

  func start(_ command: CDVInvokedUrlCommand) {
    self.startCommand = command

    guard let success = self.psiphonTunnel?.start(true), success else {
        NSLog("psiphonTunnel.start returned false")
        return
    }
    let reachability = Reachability.forInternetConnection()
    let networkStatus = reachability?.currentReachabilityStatus()
    NSLog("Internet is reachable? \(networkStatus != NotReachable)")
  }

  func pause(_ command: CDVInvokedUrlCommand) {
    let pluginResult = CDVPluginResult(
      status: CDVCommandStatus_OK
    )

		self.psiphonTunnel!.stop()
    self.closeSession()

    self.commandDelegate!.send(
      pluginResult,
      callbackId: command.callbackId
    )
  }

  func port(_ command: CDVInvokedUrlCommand) {
    let pluginResult = CDVPluginResult(
      status: CDVCommandStatus_OK,
      messageAs: [PSICordova.httpProxyPort]
    )

    self.commandDelegate!.send(
      pluginResult,
      callbackId: command.callbackId
    )
  }

  override func dispose() {
		NSLog("Stopping tunnel")
		self.psiphonTunnel?.stop()
  }

  func openSession() {
		let socksProxyPort = self.psiphonTunnel!.getLocalSocksProxyPort()
		assert(socksProxyPort > 0)

		let config = URLSessionConfiguration.ephemeral
		config.requestCachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
		config.connectionProxyDictionary = [AnyHashable: Any]()

		// Enable and set the SOCKS proxy values.
		config.connectionProxyDictionary?[kCFStreamPropertySOCKSProxy as String] = 1
		config.connectionProxyDictionary?[kCFStreamPropertySOCKSProxyHost as String] = "127.0.0.1"
		config.connectionProxyDictionary?[kCFStreamPropertySOCKSProxyPort as String] = socksProxyPort

		self.session = URLSession.init(configuration: config, delegate: nil, delegateQueue: OperationQueue.current)

    let pluginResult = CDVPluginResult(
      status: CDVCommandStatus_OK
    )

    self.commandDelegate!.send(
      pluginResult,
      callbackId: self.startCommand!.callbackId
    )
  }

  func closeSession() {
		self.session?.invalidateAndCancel()
    self.session = nil
  }

	func makeRequestViaUrlSessionProxy(_ request: URLRequest,_ callback: @escaping (_ data: Data?,_ response: URLResponse?,_ error: Error?) -> ()) {
		// Create the URLSession task that will make the request via the tunnel proxy.
		let task = self.session?.dataTask(with: request) {
			(data: Data?, response: URLResponse?, error: Error?) in
      callback(data, response, error)
		}

		// Start the request task.
		task?.resume()
  }
}

// MARK: TunneledAppDelegate implementation
// See the protocol definition for details about the methods.
// Note that we're excluding all the optional methods that we aren't using,
// however your needs may be different.
extension PSICordova: TunneledAppDelegate {

  func getPsiphonConfig() -> Any? {
    return self.psiphonConfig
  }

  /// Read the Psiphon embedded server entries resource file and return the contents.
  /// * returns: The string of the contents of the file.
  func getEmbeddedServerEntries() -> String? {
    return ""
  }

  func onDiagnosticMessage(_ message: String) {
      NSLog("onDiagnosticMessage: %@", message)
  }

    func onConnected() {
        NSLog("onConnected")
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: self.startCommand?.callbackId
        )
    }

  func onListeningSocksProxyPort(_ port: Int) {
      DispatchQueue.main.async {
          JAHPAuthenticatingHTTPProtocol.resetSharedDemux()
          PSICordova.socksProxyPort = port
      }
  }

  func onListeningHttpProxyPort(_ port: Int) {
      DispatchQueue.main.async {
          JAHPAuthenticatingHTTPProtocol.resetSharedDemux()
          PSICordova.httpProxyPort = port
      }
  }
}

extension PSICordova: JAHPAuthenticatingHTTPProtocolDelegate {

}
