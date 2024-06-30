import UIKit
import ARKit
import SceneKit

class PlayerViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    var modelNode: SCNNode?
    private var currentAngleY: Float = 0.0 //need to start at 0 so looking straight
    //private because onyl want in this scope

    override func viewDidLoad() {
        super.viewDidLoad()

        //  ARSCNView delegate
        sceneView.delegate = self
        sceneView.scene = SCNScene() // start the scene
        
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)

       
        loadUSDZModel(named: "bball_medium")

        //tap and rotate only ones need to do pinch potentially
        addGestureRecognizers()
    }

    func loadUSDZModel(named modelName: String) {
        guard let scene = SCNScene(named: "\(modelName).usdz") else {
            print("idk where this is")
            return
        }

        modelNode = SCNNode()

        //adding allows for this to happen
        for childNode in scene.rootNode.childNodes {
            modelNode?.addChildNode(childNode)
        }

        // get the model node
        modelNode?.position = SCNVector3(0, -0.5, -0.5) // Adjust position as needed

        // change the model to node to get children
        if let modelNode = modelNode {
            sceneView.scene.rootNode.addChildNode(modelNode)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Restart AR session
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the session
        sceneView.session.pause()
    }

    // MARK: - Gesture Recognizers

    func addGestureRecognizers() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let modelNode = modelNode else { return }

        if gesture.state == .changed {
            let scale = Float(gesture.scale)
            modelNode.scale = SCNVector3(scale, scale, scale)
        }
    }

    
    //handles the rotation
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let modelNode = modelNode else { return }

        let translation = gesture.translation(in: gesture.view)
        let newAngleY = Float(translation.x) * (Float.pi / 180.0)
        
        if gesture.state == .changed {
            currentAngleY += newAngleY
            modelNode.eulerAngles.y = currentAngleY
            gesture.setTranslation(.zero, in: gesture.view)
        }
    }
}
