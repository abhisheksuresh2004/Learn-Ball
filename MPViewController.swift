import UIKit
import ARKit
import MultipeerConnectivity

class MPViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var chatTableView: UITableView!
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var messageTextField: UITextField!
    
    var multipeerSession: MCSession?
    var peerID: MCPeerID?
    var browser: MCBrowserViewController?
    var assistant: MCAdvertiserAssistant?
    
    var messages: [String] = []
    var pictureNodes: [SCNNode] = []
    var currentPictureIndex = 0
    
   
    
    let imageNames = [
        "Midterm 2 Statistics.png",
        "Motion-Strong-3.png",
       
        // Add more image names here
    ]
    
    
    // Initialize an array to hold UIImage objects
    var pictures: [UIImage] = []
    

    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("nothing")
        print(imageNames)
        
        // Ensure outlets are not nil
        guard let sceneView = sceneView else {
            print("sceneView outlet is not connected")
            return
        }
        guard let chatTableView = chatTableView else {
            print("chatTableView outlet is not connected")
            return
        }
        guard let messageTextField = messageTextField else {
            print("messageTextField outlet is not connected")
            return
        }
        guard let sendButton = sendButton else {
            print("sendButton outlet is not connected")
            return
        }
        
        // Register the cell class
        chatTableView.register(UITableViewCell.self, forCellReuseIdentifier: "MessageCell")
        
        // Set up ARSCNView
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        
        // Configure ARKit session
        let configuration = ARWorldTrackingConfiguration()
        configuration.isCollaborationEnabled = true
        sceneView.session.run(configuration)
        
        // Set up Multipeer Connectivity
        setUpMultipeerConnectivity()
        loadImages()
        
        // Add gesture recognizers
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        let swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeftGestureRecognizer.direction = .left
        sceneView.addGestureRecognizer(swipeLeftGestureRecognizer)
        
        let swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRightGestureRecognizer.direction = .right
        sceneView.addGestureRecognizer(swipeRightGestureRecognizer)
        
        // Set up chat UI
        chatTableView.delegate = self
        chatTableView.dataSource = self
        messageTextField.delegate = self
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        
        // Initialize picture nodes
        createPictureNodes()
        displayCurrentPicture()
    }
    
    func loadImages() {
        print("inside here")
        //            for imageName in imageNames {
        //                let resourceName = "\(resourceGroupName)/\(imageName)"
        //                if let image = UIImage(named: resourceName) {
        //                    pictures.append(image)
        //                } else {
        //                    print("Error: Image \(resourceName) not found")
        //                    // Handle the case where the image is not found
        //                }
        //            }
        //        let image = UIImage(named: "IMG_8939")
        //        pictures.append(image!)
        //        let image1 = UIImage(named: "diagramstrap")
        for imageName in imageNames {
                    if let image = UIImage(named: imageName) {
                        pictures.append(image)
                    } else {
                        print("Error: Image '\(imageName)' not found")
                    }
                }
        }
        
    
        
    
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let participantAnchor = anchor as? ARParticipantAnchor {
                let node = createSphereNode()
                node.name = participantAnchor.sessionIdentifier?.uuidString
                sceneView.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let participantAnchor = anchor as? ARParticipantAnchor {
                if let node = sceneView.scene.rootNode.childNode(withName: participantAnchor.sessionIdentifier!.uuidString, recursively: true) {
                    node.simdTransform = participantAnchor.transform
                }
            }
        }
    }
    
    // MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected to \(peerID.displayName)")
        case .connecting:
            print("Connecting to \(peerID.displayName)")
        case .notConnected:
            print("Disconnected from \(peerID.displayName)")
        @unknown default:
            fatalError()
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.messages.append("\(peerID.displayName): \(message)")
                self.chatTableView.reloadData()
                self.scrollToBottom()
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
    
    // MARK: - MCBrowserViewControllerDelegate
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Multipeer Connectivity Setup
    
    func setUpMultipeerConnectivity() {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        guard let peerID = peerID else { return }
        
        multipeerSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        guard let multipeerSession = multipeerSession else { return }
        
        multipeerSession.delegate = self
        
        browser = MCBrowserViewController(serviceType: "ar-collab", session: multipeerSession)
        browser?.delegate = self
        
        assistant = MCAdvertiserAssistant(serviceType: "ar-collab", discoveryInfo: nil, session: multipeerSession)
        assistant?.start()
    }
    
    // MARK: - Interaction Handlers
    
    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let sceneView = sceneView else { return }
        
        let location = gestureRecognizer.location(in: sceneView)
        if let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any) {
            let results = sceneView.session.raycast(query)
            if let result = results.first {
                let anchor = ARAnchor(name: "shared", transform: result.worldTransform)
                sceneView.session.add(anchor: anchor)
                
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
                    sendToAllPeers(data)
                }
            }
        }
    }
    
    @objc func handleSwipe(_ gestureRecognizer: UISwipeGestureRecognizer) {
        if gestureRecognizer.direction == .left {
            showNextPicture()
        } else if gestureRecognizer.direction == .right {
            showPreviousPicture()
        }
    }
    
    @objc func sendMessage() {
        guard let message = messageTextField.text, !message.isEmpty else { return }
        let data = Data(message.utf8)
        
        sendToAllPeers(data)
        
        messages.append("Me: \(message)")
        chatTableView.reloadData()
        scrollToBottom()
        
        messageTextField.text = ""
    }
    
    // MARK: - Helper Methods
    
    func createSphereNode() -> SCNNode {
        let sphere = SCNSphere(radius: 0.05)
        sphere.firstMaterial?.diffuse.contents = UIColor.blue
        return SCNNode(geometry: sphere)
    }
    
    func sendToAllPeers(_ data: Data) {
        guard let multipeerSession = multipeerSession else { return }
        do {
            try multipeerSession.send(data, toPeers: multipeerSession.connectedPeers, with: .reliable)
        } catch {
            print("Error sending data: \(error.localizedDescription)")
        }
    }
    
    func scrollToBottom() {
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    // Create AR picture nodes
    func createPictureNodes() {
        print("inside here bro")
        for picture in pictures {
            let plane = SCNPlane(width: 0.3, height: 0.2)
            plane.firstMaterial?.diffuse.contents = picture
            let node = SCNNode(geometry: plane)
            node.isHidden = true // Hide all nodes initially
            pictureNodes.append(node)
            sceneView.scene.rootNode.addChildNode(node)
        }
    }
    
    // Display the current picture in AR
    func displayCurrentPicture() {
        
        for (index, node) in pictureNodes.enumerated() {
            node.isHidden = index != currentPictureIndex
        }
    }
    
    // Show the next picture
    // Show the next picture
    func showNextPicture() {
        guard pictures.count > 0 else {
            print("Error: No pictures available.")
            return
        }
        currentPictureIndex = (currentPictureIndex + 1) % pictures.count
        displayCurrentPicture()
    }

    // Show the previous picture
    func showPreviousPicture() {
        guard pictures.count > 0 else {
            print("Error: No pictures available.")
            return
        }
        currentPictureIndex = (currentPictureIndex - 1 + pictures.count) % pictures.count
        displayCurrentPicture()
    }

    // MARK: - UITableViewDelegate & UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath)
        cell.textLabel?.text = messages[indexPath.row]
        return cell
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        sendMessage()
        return true
    }
}
