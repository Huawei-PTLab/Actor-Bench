import Foundation
import Sam

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0

enum NodeMessage: Message {
    case connect(KnownActorRef<NodeActor>)
    case start
    case token(id: Int, value: Int)
}

struct NodeActor: Actor {
    unowned let actorContext: KnownActorCell<NodeActor>
    var context: ActorCell {
        get { return actorContext }
    }

    typealias ActorMessage = NodeMessage
    
    var nextNode: KnownActorRef<NodeActor>!
    let nodeId: Int
    let initValue: Int
    
    init(context: KnownActorCell<NodeActor>, id: Int, initValue: Int) {
        self.actorContext = context
        self.nodeId = id
        self.initValue = initValue
    }
    
    mutating func receive(_ msg: NodeMessage) {
        switch msg {
        case .connect(let next):
            nextNode = next
        case .start:
            startTime = Date().timeIntervalSince1970
            print("Start: \(Date())")
            nextNode.tell(.token(id: nodeId, value: initValue))
        case .token(let id, let value):
            if value == 0 {
                endTime = Date().timeIntervalSince1970
                print(nodeId)
                print("Stop: \(Date())")
                print("Duration: \(endTime - startTime)")
                exit(0)
            } else {
                nextNode.tell(.token(id: id, value: value - 1))
            }
        }
    }
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

let nNodes = Int(CommandLine.arguments[1])!
let initValue = Int(CommandLine.arguments[2])!
print("Ring size: \(nNodes)")
print("Initial message value: \(initValue)")
let system = ActorSystem(name: "Ring2", dispatcher: ShareDispatcher(queues: 1))
var nodes = [KnownActorRef<NodeActor>]()

for i in 0..<nNodes {
    var node = system.actorOf(name: "Node\(i)") { context in
        NodeActor(context: context, id: i, initValue: initValue)
    }
    nodes.append(node)
}

for i in 0..<nNodes {
    nodes[i].tell(.connect(nodes[(i+1)%nNodes]))
}

nodes[0].tell(.start)

sleep(300)
