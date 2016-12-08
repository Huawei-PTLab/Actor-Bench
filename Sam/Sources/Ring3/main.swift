import Sam
import Foundation

enum PassMessage: Message {
    case connect(KnownActorRef<Passer>)
    case token(Int)
}

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0
var nNodes = 3
var nRounds = 10

struct Passer: Actor {
    unowned let actorContext: KnownActorCell<Passer>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = PassMessage
    
	let nodeId: Int
	weak var partner: KnownActorRef<Passer>! = nil

    init(context: KnownActorCell<Passer>, id: Int, partner: KnownActorRef<Passer>? = nil) {
        self.actorContext = context
		self.nodeId = id
		self.partner = partner
	}

	func receive(_ msg: PassMessage) {
		switch(msg) {
        case .connect(let partner):
            self.partner = partner
		case .token(let tokenCount):
            let count = tokenCount + 1
            if count >= nRounds {
                endTime = Date().timeIntervalSince1970
                print("Stop: \(Date())")
                print("Duration: \(endTime - startTime)")
                exit(0)
                // Tell the rest of the ring to stop
                partner ! .poisonPill
            } else {
                partner ! .token(count)
            }
		default:
			print("Actor \(nodeId) got unexpected message: \(msg)")
		}
	}
    
    mutating func close(partner: KnownActorRef<Passer>) {
        self.partner = partner
    }
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

if let nodes = Int(CommandLine.arguments[1]) {
    nNodes = nodes
}
if let rounds = Int(CommandLine.arguments[2]) {
    nRounds = rounds
}
print("Ring size: \(nNodes)")
print("Number of rounds: \(nRounds)")
//let system = ActorSystem(name: "Ring3")
let system = ActorSystem(name: "Ring3", dispatcher: ShareDispatcher(queues: 1))
var passers = [KnownActorRef<Passer>]()
passers.append(system.actorOf(name: "Passer0") { context in
    Passer(context: context, id: 0)
    })
for i in 1..<nNodes {
    var passer = system.actorOf(name: "Passer\(i)") { context in
        Passer(context: context, id: i, partner: passers[i-1])
    }
    passers.append(passer)
}
passers[0] ! PassMessage.connect(passers[nNodes - 1])

startTime = Date().timeIntervalSince1970
print("Start: \(Date())")
passers[0] ! PassMessage.token(0)
sleep(30)	// wait to complete
