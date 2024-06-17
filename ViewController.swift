import ARKit
import SceneKit
import UIKit
import AVKit

struct Quiz {
    let question: String
    let answers: [String]
    let correctAnswerIndex: Int
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    let quizzes: [String: Quiz] = [
        "Screenshot-2016-11-22-14": Quiz(question: "What spot should the driver kick to?", answers: ["2", "3", "4"], correctAnswerIndex: 1),
        "diagramstrap": Quiz(question: "What is this play called?", answers: ["Trap     ", "Zone"], correctAnswerIndex: 0),
        "Piston-Elevator-Man-To-Man-Play": Quiz(question: "What positions are closing the gate?", answers: ["4,5", "1,2", "1,3"], correctAnswerIndex: 0)
    ]
    
    var player: AVPlayer?
    var videoNode: SCNNode?
    
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".serialSceneKitQueue")
    
    var session: ARSession {
        return sceneView.session
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self

        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }

    var isRestartAvailable = true

    func resetTracking() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources Basketball", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5 , messageType: .contentPlacement)
    }

    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)  {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        let width = CGFloat(referenceImage.physicalSize.width)
        let height = CGFloat(referenceImage.physicalSize.height)

        let videoHolder = SCNNode()
        let planeHeight = height / 2
        
        let scale = SCNVector3(x: 3, y: 3, z: 3)
        videoHolder.scale = scale
        
        let videoHolderGeometry = SCNPlane(width: width, height: planeHeight)
        videoHolder.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        videoHolder.geometry = videoHolderGeometry
        let zPosition = height - (planeHeight / 2)
        videoHolder.position = SCNVector3(0, 0, -zPosition)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemEnd(notification:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, userInfo: ["imageName": referenceImage.name])

        if referenceImage.name == "Screenshot-2016-11-22-14" {
            if let videoURL = Bundle.main.url(forResource: "drive and kick", withExtension: "mp4") {
                setupVideoOnNode(videoHolder, fromURL: videoURL)
            }
        } else if referenceImage.name == "diagramstrap" {
            if let videoURL = Bundle.main.url(forResource: "trapVideo", withExtension: "mp4") {
                setupVideoOnNode(videoHolder, fromURL: videoURL)
            }
        }

        node.addChildNode(videoHolder)
        videoNode = videoHolder
    }
    
    @objc func playerItemEnd(notification: Notification) {
        print("Video finished playing")
        videoNode?.removeFromParentNode()
        videoNode = nil
        
        if let userInfo = notification.userInfo, let imageName = userInfo["imageName"] as? String {
            clearQuizNodes() // Clear existing quiz nodes before setting up a new quiz
            setupQuiz(forImageName: imageName)
        }
    }
    
    func setupQuiz(forImageName imageName: String) {
        guard let quiz = quizzes[imageName] else {
            print("No quiz found for image: \(imageName)")
            return
        }

        // Create and position quiz nodes
        let questionNode = createTextNode(text: quiz.question, position: SCNVector3(0, 0.3, -0.5))
        questionNode.name = "question"
        sceneView.scene.rootNode.addChildNode(questionNode)
        
        for (index, answer) in quiz.answers.enumerated() {
            let answerNode = createTextNode(text: answer, position: SCNVector3(Float(index - 1) * 0.3, 0, -0.5))
            answerNode.name = index == quiz.correctAnswerIndex ? "correct" : "wrong"
            sceneView.scene.rootNode.addChildNode(answerNode)
        }
    }

    func createTextNode(text: String, position: SCNVector3) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 1.0)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.black
        let textNode = SCNNode(geometry: textGeometry)
        textNode.position = position
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        return textNode
    }

    @objc func handleTap(_ gestureRecognize: UITapGestureRecognizer) {
        let touchLocation = gestureRecognize.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(touchLocation, options: nil)
        
        if let node = hitTestResults.first?.node {
            print("Tapped node: \(node.name ?? "unknown")")
            if node.name == "correct" {
                showResult(message: "Correct!")
                clearQuizNodes() // Clear all quiz nodes when the correct answer is chosen
            } else if node.name == "wrong" {
                showResult(message: "Wrong, try again.")
            }
        }
    }

    func clearQuizNodes() {
        sceneView.scene.rootNode.childNodes.filter { $0.name == "question" || $0.name == "correct" || $0.name == "wrong" }.forEach { $0.removeFromParentNode() }
    }

    func showResult(message: String) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true, completion: nil)
    }
    
    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
    
    func setupVideoOnNode(_ node: SCNNode, fromURL url: URL) {
        var videoPlayerNode: SKVideoNode!
        let videoPlayer = AVPlayer(url: url)
        videoPlayerNode = SKVideoNode(avPlayer: videoPlayer)
        videoPlayerNode.yScale = -1
        let spriteKitScene = SKScene(size: CGSize(width: 1200, height: 800))
        spriteKitScene.scaleMode = .aspectFit
        videoPlayerNode.position = CGPoint(x: spriteKitScene.size.width / 2, y: spriteKitScene.size.height / 2)
        videoPlayerNode.size = spriteKitScene.size
        spriteKitScene.addChild(videoPlayerNode)
        node.geometry?.firstMaterial?.diffuse.contents = spriteKitScene
        videoPlayerNode.play()
        videoPlayer.volume = 0.8
    }
}

