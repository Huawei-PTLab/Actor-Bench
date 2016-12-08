import Sam
import Foundation

enum ForkMessage: Message {
    case stop
    case start
    case timeStamp(Double)
}


struct Node: Actor {
    unowned let actorContext: KnownActorCell<Node>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = ForkMessage

	let currentLevel: Int
	let maxLevel: Int
	let root: KnownActorRef<RootNode>
	var lChild: KnownActorRef<Node>?
	var rChild: KnownActorRef<Node>?

    init(context: KnownActorCell<Node>, currentLevel: Int, root: KnownActorRef<RootNode>, maxLevel: Int) {
        self.actorContext = context
		self.currentLevel = currentLevel
		self.root = root
		self.maxLevel = maxLevel
	}

	mutating func receive(_ msg: ForkMessage) {
		switch(msg) {
		case .start:
			if currentLevel >= maxLevel {
				// reach the maximum level
				let endTime = Date().timeIntervalSince1970
				root ! .timeStamp(endTime)
			} else {
                let root = self.root
                let level = self.currentLevel + 1
                let maxLevel = self.maxLevel
                self.lChild = context.actorOf(name: "LN\(currentLevel + 1)", { (context: KnownActorCell<Node>) in Node(context: context, currentLevel: level, root: root, maxLevel: maxLevel) })
                self.rChild = context.actorOf(name: "RN\(currentLevel + 1)", { (context: KnownActorCell<Node>) in Node(context: context, currentLevel: level, root: root, maxLevel: maxLevel) })
				self.lChild! ! .start
				self.rChild! ! .start
			}
		case .stop:
			if let left = self.lChild {
				left ! .stop
			}
			if let right = self.rChild {
				right ! .stop
			}
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
    
    typealias ActorMessage = ForkMessage
    
    var timeStampCount = 0
	let startTime: Double = Date().timeIntervalSince1970
	var endTime: Double = 0.0
	var lChild: KnownActorRef<Node>?
	var rChild: KnownActorRef<Node>?
	let maxLevel: Int

    init(context: KnownActorCell<RootNode>, maxLevel: Int) {
        self.actorContext = context
		self.maxLevel = maxLevel
	}

	mutating func receive(_ msg: ForkMessage) {
		switch(msg) {
		case .start:
			print("Started: \(Date())")
			if maxLevel == 1 {
				let endTime = Date().timeIntervalSince1970
				ref ! .timeStamp(endTime)
			} else {
                unowned let ref = self.ref
                let maxLevel = self.maxLevel
                self.lChild = context.actorOf(name: "LN2", { context in Node(context: context, currentLevel: 2, root: ref, maxLevel: maxLevel) })
                self.rChild = context.actorOf(name: "RN2", { context in Node(context: context, currentLevel: 2, root: ref, maxLevel: maxLevel) })
				self.lChild! ! .start
				self.rChild! ! .start
			}
		case .timeStamp(let endTime):
			if endTime > self.endTime {
				self.endTime = endTime
			}
			self.timeStampCount += 1
			if self.timeStampCount == Int(pow(2.0, Double(maxLevel - 1))) {
				print("Finished: \(Date())")
				print("Duration: \(self.endTime - self.startTime)")
				exit(0)
				if let left = self.lChild {
					left ! .stop
				}
				if let right = self.rChild {
					right ! .stop
				}
			}
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

let maxLevel = Int(CommandLine.arguments[1])!
let system = ActorSystem(name: "fork")
let root = system.actorOf(name: "root", { context in RootNode(context: context, maxLevel: maxLevel) })
root ! .start
sleep(3000)	// wait to complete
