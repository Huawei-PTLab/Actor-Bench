import Sam
import Foundation

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0

enum NodeMessage: Message {
    case start
    case connect(next: KnownActorRef<NodeActor>)
    case token(Int)
}

struct NodeActor: Actor {
    unowned let actorContext: KnownActorCell<NodeActor>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = NodeMessage
    
	let nodeId: Int
	let nRounds: Int
	var nextNode: KnownActorRef<NodeActor>!	= nil
	var returnCount: Int = 0

	init(context: KnownActorCell<NodeActor>, args: [Int]) {
        self.actorContext = context
		self.nodeId = args[0]
		self.nRounds = args[1]
	}

	mutating func receive(_ msg: NodeMessage) {
		switch(msg) {
        case .connect(let next):
			self.nextNode = next
		case .start:
			startTime = Date().timeIntervalSince1970
			print("Start: \(Date())")
			for _ in 0..<nRounds {
                nextNode ! .token(nodeId)
			}
        case .token(let id):
			if id == nodeId {
				returnCount += 1
				if returnCount == nRounds {
					endTime = Date().timeIntervalSince1970
					print("Stop: \(Date())")
					print("Duration: \(endTime - startTime)")
					exit(0)
				}
			}
			nextNode ! .token(id)
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

let nNodes = Int(CommandLine.arguments[1])!
let nRounds = Int(CommandLine.arguments[2])!
print("Ring size: \(nNodes)")
print("Number of rounds: \(nRounds)")
let system = ActorSystem(name: "Ring")
var nodes = [KnownActorRef<NodeActor>]()
for i in 0..<nNodes {
    var node = system.actorOf(name: "Node\(i)") {
        context in NodeActor(context:context, args:[i, nRounds])
    }
	nodes.append(node)
}

for i in 0..<nNodes {
    nodes[i] ! .connect(next: nodes[(i+1)%nNodes])
}

nodes[0] ! NodeMessage.start
sleep(30)	// wait to complete
