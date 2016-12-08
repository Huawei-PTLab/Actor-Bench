import Sam
import Foundation
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

enum TreeMessage: Message {
    case token(sender: KnownActorRef<RootNode>)
    case response
    case createTree
    case timeStamp(Double)
}

struct Node: Actor {
    unowned let actorContext: KnownActorCell<Node>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = TreeMessage

	let level: Int
	let maxLevel: Int
	let root: KnownActorRef<RootNode>
	var lChild: KnownActorRef<Node>?
	var rChild: KnownActorRef<Node>?

    init(context: KnownActorCell<Node>, level: Int, root: KnownActorRef<RootNode>, maxLevel: Int) {
        self.actorContext = context
		self.level = level
		self.root = root
		self.maxLevel = maxLevel
	}

    mutating func receive(_ msg: TreeMessage) {
		switch(msg) {
		case .createTree:
			if level == maxLevel {
				// reach the maximum level
				let endTime = Date().timeIntervalSince1970
				root ! .timeStamp(endTime)
			} else {
                let level = self.level + 1
                let maxLevel = self.maxLevel
                let root = self.root
                self.lChild = context.actorOf(name: "LN\(level + 1)", { context in Node(context: context, level: level, root: root, maxLevel: maxLevel) })
                self.rChild = context.actorOf(name: "RN\(level + 1)", { context in Node(context: context, level: level, root: root, maxLevel: maxLevel) })
				self.lChild! ! .createTree
				self.rChild! ! .createTree
			}
		case .token(let sender):
			guard lChild != nil && rChild != nil else {
				sender ! .response	// send response to root node
				return
			}
            lChild! ! TreeMessage.token(sender: sender)	// send response to root node
			rChild! ! TreeMessage.token(sender: sender)
		default:
			print("Unexpected message")
		}
	}

    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

struct RootNode: Actor {
    unowned let actorContext: KnownActorCell<RootNode>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = TreeMessage
    
	var timeStampCount = 0
	var startTime: Double = Date().timeIntervalSince1970
	var endTime: Double = 0.0
	var lChild: KnownActorRef<Node>?
	var rChild: KnownActorRef<Node>?
	var responseCount: Int = 0
	let maxLevel: Int
	var totalLeafNode: Int {
		return Int(pow(2.0, Double(maxLevel - 1)))
	}
	let nMsg: Int

    init(context: KnownActorCell<RootNode>, maxLevel: Int, nMsg: Int) {
        self.actorContext = context
		self.maxLevel = maxLevel
		self.nMsg = nMsg
	}

	mutating func receive(_ msg: TreeMessage) {
		switch(msg) {
		case .createTree:
			print("Start creating tree: \(Date())")
			if maxLevel == 1 {
				let endTime = Date().timeIntervalSince1970
				ref ! TreeMessage.timeStamp(endTime)
			} else {
                unowned let ref = self.ref
                let maxLevel = self.maxLevel
                self.lChild = context.actorOf(name: "LN2", { context in Node(context: context, level: 2, root: ref, maxLevel: maxLevel) })
                self.rChild = context.actorOf(name: "RN2", { context in Node(context: context, level: 2, root: ref, maxLevel: maxLevel) })
				self.lChild! ! .createTree
				self.rChild! ! .createTree
			} 
		case .timeStamp(let endTime):
			if endTime > self.endTime {
				self.endTime = endTime
			}
			self.timeStampCount += 1
			if self.timeStampCount == totalLeafNode {
				print("Finish creating tree: \(Date())")
				print("Duration: \(self.endTime - self.startTime)")
				print("Start message passing: \(Date())")
				startTime = Date().timeIntervalSince1970
				guard lChild != nil && rChild != nil else {
					ref ! TreeMessage.response
					return
				}
				for _ in 1...nMsg {
					lChild! ! TreeMessage.token(sender: ref)
					rChild! ! TreeMessage.token(sender: ref)
				}
			}
		case .response:
			responseCount += 1
			if responseCount == totalLeafNode * nMsg {
				self.endTime = Date().timeIntervalSince1970
				print("Finish message passing: \(Date())")
				print("Duration: \(self.endTime - self.startTime)")
				exit(0)
			}
        default:
            print("RootNode received unexpected message")
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

let maxLevel = Int(CommandLine.arguments[1])!
let nMsg = Int(CommandLine.arguments[2])!
let system = ActorSystem(name: "TreeMsg")
let root = system.actorOf(name: "root", { context in RootNode(context: context, maxLevel: maxLevel, nMsg: nMsg) })
root ! .createTree
sleep(300)	// wait to complete
