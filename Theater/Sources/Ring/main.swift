import Theater
import Foundation

// Messages
class Start: Actor.Message {}
class Stop: Actor.Message {}
class Connect: Actor.Message {
	let next: ActorRef

	init(_ next: ActorRef, sender: ActorRef?) {
		self.next = next
		super.init(sender: sender)
	}
}
class Token: Actor.Message {
	let id: Int
	init(id: Int, sender: ActorRef?) {
		self.id = id
		super.init(sender: sender)
	}
}

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0

class NodeActor: Actor {
	let nodeId: Int
	let nRounds: Int
	var nextNode: ActorRef!	= nil
	var returnCount: Int = 0

	required init(context: ActorCell, args: [Int]) {
		self.nodeId = args[0]
		self.nRounds = args[1]
		super.init(context: context)
	}

	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case let connect as Connect:
			self.nextNode = connect.next
		case is Start:
			startTime = Date().timeIntervalSince1970
			print("Start: \(Date())")
			for _ in 0..<nRounds {
				nextNode ! Token(id: nodeId, sender: this)
			}
		case let token as Token:
            if token.id == nodeId {
				returnCount += 1
				if returnCount == nRounds {
					endTime = Date().timeIntervalSince1970
					print("Stop: \(Date())")
					print("Duration: \(endTime - startTime)")
                    // The right way to shut down the system is call shutdown()
                    // Calling exit(0) is faster and doesn't matter in a benchmark
                    // context.system.shutdown()
                    exit(0)
				}
            } else {
			    nextNode ! Token(id: token.id, sender: this)
            }
		default:
			print("Actor \(nodeId) got unexpected message: \(msg)")
		}
	}
}

let nNodes = Int(CommandLine.arguments[1])!
let nRounds = Int(CommandLine.arguments[2])!
print("Ring size: \(nNodes)")
print("Number of rounds: \(nRounds)")
let system = ActorSystem(name: "Ring")
var nodes = [ActorRef]()
for i in 0..<nNodes {
    var node = system.actorOf(name: "Node\(i)") {
        context in NodeActor(context:context, args:[i, nRounds])
    }
	nodes.append(node)
}

for i in 0..<nNodes {
	nodes[i] ! Connect(nodes[(i+1)%nNodes], sender: nil)
}

nodes[0] ! Start(sender: nil)
_ = system.waitFor(seconds:300)	// wait to complete or timeout in 6 mins
