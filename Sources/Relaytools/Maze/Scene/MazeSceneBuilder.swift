import AppKit
@preconcurrency import SceneKit

@MainActor
final class MazeSceneBuilder {
    let scene = SCNScene()
    let camera = SCNNode()
    var characterNodes: [Int: SCNNode] = [:]
    var barrierNodes: [Int: SCNNode] = [:]
    var headNodes: [Int: SCNNode] = [:]
    var gateSideways: [Int: Bool] = [:]
    private let teal = NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.68, alpha: 1)
    private let amber = NSColor(calibratedRed: 1, green: 0.67, blue: 0.28, alpha: 1)

    init(layout: MazeLayout, customers: [MazeCustomer]) {
        scene.background.contents = NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.09, alpha: 1)
        scene.fogColor = NSColor(calibratedRed: 0.055, green: 0.08, blue: 0.12, alpha: 1)
        scene.fogStartDistance = 16
        scene.fogEndDistance = 36
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = NSColor(calibratedRed: 0.65, green: 0.75, blue: 0.88, alpha: 1)
        ambient.light?.intensity = 420
        scene.rootNode.addChildNode(ambient)

        let wall = material(NSColor(calibratedRed: 0.26, green: 0.31, blue: 0.36, alpha: 1), roughness: 0.65)
        let floor = material(NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.22, alpha: 1), roughness: 0.6)
        let ceiling = material(NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.18, alpha: 1), roughness: 0.75)
        let trim = material(teal, emission: teal.withAlphaComponent(0.4))
        let lightStrip = material(NSColor.white, emission: NSColor(calibratedRed: 0.65, green: 0.88, blue: 1, alpha: 1))
        let size = MazeLayout.cellSize

        for z in 0..<layout.size {
            for x in 0..<layout.size {
                let cell = MazeCell(x: x, z: z)
                let p = layout.world(cell)
                if layout.floors.contains(cell) {
                    addBox(width: size - 0.025, height: 0.13, depth: size - 0.025, at: SCNVector3(p.x, -0.065, p.z), material: floor, bevel: 0.015)
                    addBox(width: size, height: 0.14, depth: size, at: SCNVector3(p.x, 3.12, p.z), material: ceiling)
                    if (x + z) % 3 == 0 {
                        addBox(width: 0.09, height: 0.025, depth: 1.65, at: SCNVector3(p.x, 3.035, p.z), material: lightStrip)
                        let light = SCNNode()
                        light.light = SCNLight()
                        light.light?.type = .omni
                        light.light?.intensity = 330
                        light.light?.attenuationStartDistance = 1
                        light.light?.attenuationEndDistance = 8
                        light.light?.color = NSColor(calibratedRed: 0.78, green: 0.9, blue: 1, alpha: 1)
                        light.position = SCNVector3(p.x, 2.7, p.z)
                        scene.rootNode.addChildNode(light)
                    }
                    // Recessed architectural guide lights at corridor edges.
                    for (dx, dz) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                        let neighbour = MazeCell(x: x + dx, z: z + dz)
                        if !layout.floors.contains(neighbour) {
                            addBox(width: dx == 0 ? 2.9 : 0.025, height: 0.045, depth: dx == 0 ? 0.025 : 2.9,
                                   at: SCNVector3(p.x + Double(dx) * 1.69, 0.18, p.z + Double(dz) * 1.69), material: trim)
                        }
                    }
                } else {
                    let adjacent = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { layout.floors.contains(.init(x: x + $0.0, z: z + $0.1)) }
                    if adjacent {
                        addBox(width: size, height: 3.06, depth: size, at: SCNVector3(p.x, 1.5, p.z), material: wall, bevel: 0.025)
                    }
                }
            }
        }

        let start = layout.world(layout.start)
        floorMarker("START", at: start, color: teal)
        let exit = layout.world(layout.exit)
        floorMarker("EXIT", at: exit, color: teal)
        let exitLight = SCNNode()
        exitLight.light = SCNLight()
        exitLight.light?.type = .omni
        exitLight.light?.intensity = 600
        exitLight.light?.color = teal
        exitLight.light?.attenuationEndDistance = 8
        exitLight.position = SCNVector3(exit.x, 2, exit.z)
        scene.rootNode.addChildNode(exitLight)

        // Tiny floor beacons lead through the route while leaving side passages explorable.
        for (index, cell) in layout.path.enumerated() where index % 2 == 0 {
            let p = layout.world(cell)
            let node = SCNNode(geometry: SCNCylinder(radius: 0.055, height: 0.009))
            node.geometry?.firstMaterial = trim
            node.position = SCNVector3(p.x, 0.012, p.z)
            scene.rootNode.addChildNode(node)
        }

        for customer in customers { addCustomer(customer, layout: layout) }
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 77
        camera.camera?.zNear = 0.05
        camera.camera?.zFar = 75
        camera.camera?.wantsHDR = true
        camera.camera?.bloomIntensity = 0.05
        camera.camera?.bloomThreshold = 1.1
        camera.camera?.exposureOffset = -0.15
        let headlight = SCNNode()
        headlight.light = SCNLight()
        headlight.light?.type = .omni
        headlight.light?.intensity = 120
        headlight.light?.attenuationEndDistance = 7
        camera.addChildNode(headlight)
        scene.rootNode.addChildNode(camera)
    }

    func applyPass(_ id: Int) {
        guard let character = characterNodes[id] else { return }
        barrierNodes[id]?.runAction(.sequence([.fadeOut(duration: 0.45), .removeFromParentNode()]))
        let sideways = gateSideways[id] ?? false
        character.removeAction(forKey: "idle")
        character.runAction(.group([
            .moveBy(x: sideways ? 0 : 1.12, y: 0, z: sideways ? 1.12 : 0, duration: 0.65),
            .rotateBy(x: 0, y: 0.3, z: 0, duration: 0.65)
        ]))
        headNodes[id]?.runAction(.sequence([.rotateBy(x: 0.17, y: 0, z: 0, duration: 0.15), .rotateBy(x: -0.17, y: 0, z: 0, duration: 0.15)]))
    }

    func applyRefusal(_ id: Int) {
        headNodes[id]?.runAction(.sequence([
            .rotateBy(x: 0, y: 0.18, z: 0, duration: 0.13),
            .rotateBy(x: 0, y: -0.36, z: 0, duration: 0.26),
            .rotateBy(x: 0, y: 0.18, z: 0, duration: 0.13)
        ]))
        barrierNodes[id]?.runAction(.sequence([.fadeOpacity(to: 0.8, duration: 0.12), .fadeOpacity(to: 0.28, duration: 0.4)]))
    }

    private func material(_ color: NSColor, roughness: CGFloat = 0.6, emission: NSColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = 0.03
        if let emission { material.emission.contents = emission }
        return material
    }

    @discardableResult
    private func addBox(width: Double, height: Double, depth: Double, at position: SCNVector3, material: SCNMaterial, bevel: Double = 0) -> SCNNode {
        let node = SCNNode(geometry: SCNBox(width: width, height: height, length: depth, chamferRadius: bevel))
        node.geometry?.firstMaterial = material
        node.position = position
        scene.rootNode.addChildNode(node)
        return node
    }

    private func floorMarker(_ title: String, at point: MazePoint, color: NSColor) {
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.06, pipeRadius: 0.025))
        ring.geometry?.firstMaterial = material(color, emission: color)
        ring.position = SCNVector3(point.x, 0.025, point.z)
        scene.rootNode.addChildNode(ring)
        let sign = textNode(title, size: 0.25, color: color)
        sign.position = SCNVector3(point.x, 2.45, point.z)
        sign.constraints = [SCNBillboardConstraint()]
        scene.rootNode.addChildNode(sign)
    }

    private func textNode(_ value: String, size: CGFloat, color: NSColor) -> SCNNode {
        let text = SCNText(string: value, extrusionDepth: 0.001)
        text.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        text.flatness = 0.1
        text.firstMaterial = material(color, emission: color.withAlphaComponent(0.3))
        let node = SCNNode(geometry: text)
        let (minimum, maximum) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((maximum.x + minimum.x) / 2, minimum.y, 0)
        return node
    }

    private func addCustomer(_ customer: MazeCustomer, layout: MazeLayout) {
        let p = layout.world(customer.cell)
        let sideways = customer.cell.x.isMultiple(of: 2)
        gateSideways[customer.id] = sideways
        let barrier = SCNNode(geometry: SCNBox(width: sideways ? 0.07 : 3.25, height: 2.62, length: sideways ? 3.25 : 0.07, chamferRadius: 0.02))
        let barrierMaterial = material(amber, emission: amber.withAlphaComponent(0.5))
        barrierMaterial.transparency = 0.18
        barrierMaterial.isDoubleSided = true
        barrier.geometry?.firstMaterial = barrierMaterial
        barrier.position = SCNVector3(p.x, 1.31, p.z)
        barrier.opacity = 0.28
        scene.rootNode.addChildNode(barrier)
        barrierNodes[customer.id] = barrier

        let root = SCNNode()
        root.position = SCNVector3(p.x, 0, p.z)
        if let index = layout.path.firstIndex(of: customer.cell), index > 0 {
            let previous = layout.world(layout.path[index - 1])
            root.eulerAngles.y = CGFloat(atan2(previous.x - p.x, previous.z - p.z))
        }
        let skin = material([NSColor(calibratedRed: 0.70, green: 0.43, blue: 0.29, alpha: 1),
                             NSColor(calibratedRed: 0.91, green: 0.69, blue: 0.53, alpha: 1),
                             NSColor(calibratedRed: 0.43, green: 0.29, blue: 0.22, alpha: 1)][customer.id % 3])
        let suitColor = [teal, NSColor(calibratedRed: 0.45, green: 0.44, blue: 0.75, alpha: 1), NSColor(calibratedRed: 0.76, green: 0.45, blue: 0.28, alpha: 1)][customer.id % 3]
        let suit = material(suitColor)
        let trousers = material(NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.18, alpha: 1))
        func piece(_ geometry: SCNGeometry, _ position: SCNVector3, _ material: SCNMaterial) -> SCNNode {
            geometry.firstMaterial = material
            let node = SCNNode(geometry: geometry)
            node.position = position
            root.addChildNode(node)
            return node
        }
        _ = piece(SCNCapsule(capRadius: 0.27, height: 0.68), SCNVector3(0, 1.04, 0), suit)
        for x in [-0.15, 0.15] {
            _ = piece(SCNCapsule(capRadius: 0.105, height: 0.65), SCNVector3(x, 0.39, 0), trousers)
            _ = piece(SCNBox(width: 0.22, height: 0.12, length: 0.36, chamferRadius: 0.045), SCNVector3(x, 0.07, 0.06), trousers)
        }
        for x in [-0.34, 0.34] {
            let arm = piece(SCNCapsule(capRadius: 0.085, height: 0.56), SCNVector3(x, 1.02, 0), suit)
            arm.eulerAngles.z = CGFloat(x > 0 ? 0.12 : -0.12)
            _ = piece(SCNSphere(radius: 0.085), SCNVector3(x, 0.74, 0.02), skin)
        }
        let head = piece(SCNSphere(radius: 0.22), SCNVector3(0, 1.58, 0), skin)
        headNodes[customer.id] = head
        let hair = SCNNode(geometry: SCNSphere(radius: 0.225))
        hair.scale = SCNVector3(1, 0.5, 1)
        hair.position = SCNVector3(0, 0.14, -0.025)
        hair.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.12, green: 0.09, blue: 0.07, alpha: 1))
        head.addChildNode(hair)
        for x in [-0.073, 0.073] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.017))
            eye.position = SCNVector3(x, 0.025, 0.205)
            eye.geometry?.firstMaterial = material(.black)
            head.addChildNode(eye)
        }
        let badge = piece(SCNBox(width: 0.13, height: 0.18, length: 0.025, chamferRadius: 0.015), SCNVector3(0.12, 1.17, 0.245), material(.white))
        badge.eulerAngles.z = -0.1
        root.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.025, z: 0, duration: 1.4), .moveBy(x: 0, y: -0.025, z: 0, duration: 1.4)])), forKey: "idle")
        scene.rootNode.addChildNode(root)
        characterNodes[customer.id] = root
        let name = textNode("\(customer.id + 1) / \(customer.name)", size: 0.16, color: .white)
        name.position = SCNVector3(p.x, 2.08, p.z)
        name.constraints = [SCNBillboardConstraint()]
        scene.rootNode.addChildNode(name)
    }
}
