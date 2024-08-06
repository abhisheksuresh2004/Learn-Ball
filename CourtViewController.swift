import UIKit
import ARKit
import SceneKit

class CourtViewController: UIViewController, ARSCNViewDelegate {

//    var sceneView: ARSCNView!
    @IBOutlet var sceneView: ARSCNView!
    var modelNode: SCNNode?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize ARSCNView
        sceneView = ARSCNView(frame: self.view.frame)
        sceneView.delegate = self
        self.view.addSubview(sceneView)

        // Set up constraints to fill the main view
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: self.view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        // Start AR session
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)

        // Load USDZ file
//        loadUSDZModel(named: "bball_medium")
        loadUSDZModel(named: "004_Backetball_court_")

        // Add gesture recognizers
        addGestureRecognizers()
    }

    func loadUSDZModel(named modelName: String) {
        guard let scene = SCNScene(named: "004_Backetball_court_.usdz") else {
            print("Failed to load USDZ file.")
            return
        }

        // Create a node to hold the model
        modelNode = SCNNode()

        // Add all child nodes from the scene to the model node
        for childNode in scene.rootNode.childNodes {
            modelNode?.addChildNode(childNode)
        }

        // Position the model node
        modelNode?.position = SCNVector3(0, -0.5, -0.5) // Adjust position as needed

        // Add the model node to the ARSCNView's scene
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

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let modelNode = modelNode else { return }

        let translation = gesture.translation(in: gesture.view)
        let rotation = Float(translation.x) * (Float.pi / 180.0)
        let x = 1

        modelNode.eulerAngles.y = rotation
        gesture.setTranslation(.zero, in: gesture.view)
    }
}

