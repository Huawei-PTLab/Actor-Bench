import Theater
import Foundation
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


// Messages
class Token: Actor.Message{}
class Response: Actor.Message {}
class CreateTree: Actor.Message{}
class TimeStamp: Actor.Message {
	let endTime: Double
	init(end: Double, sender: ActorRef) {
		self.endTime = end
		super.init(sender: sender)
	}
}

class Node: Actor {

	let level: Int
	let maxLevel: Int
	let root: ActorRef
	var lChild: ActorRef?
	var rChild: ActorRef?

    init(context: ActorCell, level: Int, root: ActorRef, maxLevel: Int) {
		self.level = level
		self.root = root
		self.maxLevel = maxLevel
		super.init(context: context)
	}

	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case is CreateTree:
			if level == maxLevel {
				// reach the maximum level
				let endTime = NSDate().timeIntervalSince1970
				root ! TimeStamp(end: endTime, sender: this)
			} else {
                self.lChild = context.actorOf(name: "LN\(level + 1)", { (context: ActorCell) in Node(context: context, level: self.level + 1, root: self.root, maxLevel: self.maxLevel) })
                self.rChild = context.actorOf(name: "RN\(level + 1)", { (context: ActorCell) in Node(context: context, level: self.level + 1, root: self.root, maxLevel: self.maxLevel) })
				self.lChild! ! CreateTree(sender: nil)
				self.rChild! ! CreateTree(sender: nil)
			}
		case is Token:
			guard lChild != nil && rChild != nil else {
				msg.sender ! Response(sender: this)	// send response to root node
				return
			}
			lChild! ! Token(sender: msg.sender)	// send response to root node
			rChild! ! Token(sender: msg.sender)
		default:
			print("Unexpected message")
		}
	}
}

class RootNode: Actor {
	var timeStampCount = 0
	var startTime: Double = NSDate().timeIntervalSince1970
	var endTime: Double = 0.0
	var lChild: ActorRef?
	var rChild: ActorRef?
	var responseCount: Int = 0
	let maxLevel: Int
	var totalLeafNode: Int {
		return Int(pow(2.0, Double(maxLevel - 1)))
	}
	let nMsg: Int

    init(context: ActorCell, maxLevel: Int, nMsg: Int) {
		self.maxLevel = maxLevel
		self.nMsg = nMsg
		super.init(context: context)
	}

	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case is CreateTree:
			print("Start creating tree: \(NSDate().description)")
			if maxLevel == 1 {
				let endTime = NSDate().timeIntervalSince1970
				this ! TimeStamp(end: endTime, sender: this)
			} else {
                self.lChild = context.actorOf(name: "LN2", { (context: ActorCell) in Node(context: context, level: 2, root: self.this, maxLevel: self.maxLevel) })
                self.lChild = context.actorOf(name: "RN2", { (context: ActorCell) in Node(context: context, level: 2, root: self.this, maxLevel: self.maxLevel) })
				self.lChild! ! CreateTree(sender: nil)
				self.rChild! ! CreateTree(sender: nil)
			} 
		case let timestamp as TimeStamp:
			if timestamp.endTime > self.endTime {
				self.endTime = timestamp.endTime
			}
			self.timeStampCount += 1
			if self.timeStampCount == totalLeafNode {
				print("Finish creating tree: \(NSDate().description)")
				print("Duration: \(self.endTime - self.startTime)")
				print("Start message passing: \(NSDate().description)")
				startTime = NSDate().timeIntervalSince1970
				guard lChild != nil && rChild != nil else {
					this ! Response(sender: this)
					return
				}
				for _ in 1...nMsg {
					lChild! ! Token(sender: this)
					rChild! ! Token(sender: this)
				}
			}
		case is Response:
			responseCount += 1
			if responseCount == totalLeafNode * nMsg {
				self.endTime = NSDate().timeIntervalSince1970
				print("Finish message passing: \(NSDate().description)")
				print("Duration: \(self.endTime - self.startTime)")
				exit(0)
			}
		default:
			print("Unexpected message")
		}
	}
}

let maxLevel = Int(CommandLine.arguments[1])!
let nMsg = Int(CommandLine.arguments[2])!
let system = ActorSystem(name: "TreeMsg")
let root = system.actorOf(name: "root", { (context: ActorCell) in RootNode(context: context, maxLevel: maxLevel, nMsg: nMsg) })
root ! CreateTree(sender: nil)
sleep(300)	// wait to complete
