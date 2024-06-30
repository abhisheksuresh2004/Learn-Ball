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
    
    //need to use this to connect to the storyboard
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    //gets a string that is converted as a whole into string
    // will be useful when need to filter out and delete specfic node
    let quizzes: [String: Quiz] = [
        "Screenshot-2016-11-22-14": Quiz(question: "What spot should the driver kick to?", answers: ["2", "3", "4"], correctAnswerIndex: 1),
        "diagramstrap": Quiz(question: "What is this play called?", answers: ["Trap     ", "Zone"], correctAnswerIndex: 0),
        "Piston-Elevator-Man-To-Man-Play": Quiz(question: "What positions are closing the gate?", answers: ["4,5", "1,2", "1,3"], correctAnswerIndex: 0),
        "Sport-Basketball-Plays-1-4-low-stack-offense": Quiz(question: "Who staggers on the screen?", answers: ["1,4 ", "2", "3,4"], correctAnswerIndex: 0),

    ]
    
    //declare for the videoNode because we need the specific nodes asked for
    
    var player: AVPlayer?
    var videoNode: SCNNode?
    
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    //let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".serialSceneKitQueue")
    
    var session: ARSession {
        return sceneView.session
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //assign the object back to itself
        //delegation definition:
        sceneView.delegate = self
        sceneView.session.delegate = self

        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        
        //looks at tap when view did load to not do anythign
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
    
    
    //use this to reset the configuration

    func resetTracking() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources Basketball", bundle: nil) else {
            fatalError("where is the picture.")
        }
        
        //Need to run to get to remove existing anchors
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        statusViewController.scheduleMessage("Look around you to detect images!", inSeconds: 7.5 , messageType: .contentPlacement)
    }

    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)  {
        //use the guard to break the function
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        //dimensions
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
        else if referenceImage.name == "Piston-Elevator-Man-To-Man-Play" {
            if let videoURL = Bundle.main.url(forResource: "spurs and hawks", withExtension: "mp4") {
                    setupVideoOnNode(videoHolder, fromURL: videoURL)
                }
            }
        else if referenceImage.name == "Sport-Basketball-Plays-1-4-low-stack-offense" {
            if let videoURL = Bundle.main.url(forResource: "spurs fr", withExtension: "mp4") {
                    setupVideoOnNode(videoHolder, fromURL: videoURL)
                }
            }
          
        
        

        node.addChildNode(videoHolder)
        videoNode = videoHolder
    }
    
    @objc func playerItemEnd(notification: Notification) {
        //use this to debug the statement cause dont know where it ends
        print("Video finished playing")
        //want to end the video form playing before it goes on to the next and can remove from the parent node
        //video player has a parent node with children nodes for all of them
        videoNode?.removeFromParentNode()
        videoNode = nil
        
        //user info image refers to the ui image type so need to cast to string first
        if let userInfo = notification.userInfo, let imageName = userInfo["imageName"] as? String {
            clearQuizNodes() // Clear existing quiz nodes before setting up a new quiz
            setupQuiz(forImageName: imageName) //want to setup a new quiz
        }
    }
    
    func setupQuiz(forImageName imageName: String) {
        guard let quiz = quizzes[imageName] else {
            print("No quiz: \(imageName)")
            return
        }

        // Create and position quiz nodes
        //Need to fix this cause it can be more in the middle
        //need to account for when the question is too long
        
        let questionNode = createTextNode(text: quiz.question, position: SCNVector3(-0.7, 0.6, -0.5))
        questionNode.name = "question"
        sceneView.scene.rootNode.addChildNode(questionNode)
        
        for (index, answer) in quiz.answers.enumerated() {
            let answerNode = createTextNode(text: answer, position: SCNVector3(Float(index - 1) * 0.5, 0.4, -0.5))
            answerNode.name = index == quiz.correctAnswerIndex ? "correct" : "wrong"
            //adding the correct version for the indication when we need to print either "Correct! or incorrect!"
            sceneView.scene.rootNode.addChildNode(answerNode)
            //locaate for the childrenNode
        }
    }

    //need to use this to create the text node needed
    
    func createTextNode(text: String, position: SCNVector3) -> SCNNode {
        //need
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
        
        //need to display ansewer in the ar view, which can be done using show Result as a function
        if let node = hitTestResults.first?.node {
            print("Tapped node: \(node.name ?? "unknown")")
            if node.name == "correct" {
                showResult(message: "Correct!")
                clearQuizNodes() // clear all quiz nodes when the correct answer is chosen
            } else if node.name == "wrong" {
                showResult(message: "Wrong, try again.")
            }
        }
    }
    
    
    func showResult(message: String) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true, completion: nil)
    }

    func clearQuizNodes() {
        //done so remove from scope
        sceneView.scene.rootNode.childNodes.filter { $0.name == "question" || $0.name == "correct" || $0.name == "wrong" }.forEach { $0.removeFromParentNode() }
    }

    
    //setup video on the node which can be done using sprite kit
    func setupVideoOnNode(_ node: SCNNode, fromURL url: URL) {
        var videoPlayerNode: SKVideoNode!
        let videoPlayer = AVPlayer(url: url)
        videoPlayerNode = SKVideoNode(avPlayer: videoPlayer)
        videoPlayerNode.yScale = -1
        let spriteKitScene = SKScene(size: CGSize(width: 1800, height: 2200))
        spriteKitScene.scaleMode = .aspectFit
        videoPlayerNode.position = CGPoint(x: spriteKitScene.size.width / 2, y: spriteKitScene.size.height / 2)
        videoPlayerNode.size = spriteKitScene.size
        spriteKitScene.addChild(videoPlayerNode)
        node.geometry?.firstMaterial?.diffuse.contents = spriteKitScene
        videoPlayerNode.play()
        videoPlayer.volume = 0.8
    }
}

    
    //want to wait when displaying the video
    
    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.2),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
    
    
 
