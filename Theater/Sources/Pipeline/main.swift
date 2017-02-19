import Theater
import Foundation


// Global timer
var startTime = 0.0	// set before sending the first message to downloadActor
var endTime = 0.0	// set in WriteActor

// Messages
class PayloadMessage: Actor.Message {
	let payload: String
	init(payload: String, sender: ActorRef?) {
		self.payload = payload
		super.init(sender: sender)
	}
}
class Stop: Actor.Message {}

class DownloadActor: Actor {
	let indexer: ActorRef
    init(context: ActorCell, indexer: ActorRef) {
		self.indexer = indexer
		super.init(context: context)
	}
	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case let p as PayloadMessage:
			let newPayload = p.payload.replacingOccurrences(of: "Requested", with: "Downloaded")
			indexer ! PayloadMessage(payload: newPayload, sender: this)
		case is Stop:
			print("Downloader stopped!")
			indexer ! Stop(sender: this)
		default:
			print("Unexpected Message in DownloadActor: \(msg)")
		}
	}
}	

class IndexActor: Actor {
	let writer: ActorRef
    init(context: ActorCell, writer: ActorRef) {
		self.writer = writer
		super.init(context: context)
	}
	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case let p as PayloadMessage:
			let newPayload = p.payload.replacingOccurrences(of: "Downloaded", with: "Indexed")
			writer ! PayloadMessage(payload: newPayload, sender: this)
		case is Stop:
			print("Indexer stopped!")
			writer ! Stop(sender: this)
		default:
			print("Unexpected Message in IndexActor: \(msg)")
		}
	}
}	

class WriteActor: Actor {
	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case let p as PayloadMessage:
			let _ = p.payload.replacingOccurrences(of: "Indexed", with: "Written")
			// uncomment this to examine results
			// print(newPayload)
		case is Stop:
			print("Writer stopped!")
			endTime = Date().timeIntervalSince1970
			print("Stop: \(Date())")
			print("Duration: \(endTime - startTime)")
            // The right way to shut down the system is call shutdown()
            // Calling exit(0) is faster and doesn't matter in a benchmark
            // context.system.shutdown()
            exit(0)
        default:
			print("Unexpected Message in WriterActor: \(msg)")
		}
	}
}	

let nRequests = Int(CommandLine.arguments[1])!
let system = ActorSystem(name: "pipeline")
let writeActor = system.actorOf(name: "writer", { (context: ActorCell) in WriteActor(context: context) })
let indexActor = system.actorOf(name: "indexer", { (context: ActorCell) in IndexActor(context: context, writer: writeActor) })
let downloadActor = system.actorOf(name: "downloader", { (context: ActorCell) in DownloadActor(context: context, indexer: indexActor) })
startTime = Date().timeIntervalSince1970
print("Start: \(Date())")
for i in 1...nRequests {
	downloadActor ! PayloadMessage(payload: "Requested \(i)", sender: nil)
}
downloadActor ! Stop(sender: nil)
_ = system.waitFor(seconds:100)	// wait to complete or timeout in 100s
