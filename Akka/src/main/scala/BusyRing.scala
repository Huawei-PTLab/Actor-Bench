import java.util.Calendar
import akka.actor._

object BusyRing {
  val system = ActorSystem("BusyRing")
  var startTime: Long = 0
  var endTime: Long = 0

  def main(args: Array[String]): Unit = {
    val numNodes = args(0).toInt
    val numMessages = args(1).toInt
    val nodes =
      for (i <- 0 until numNodes) yield system.actorOf(Props(classOf[RingNode], i, numMessages), "Node" + i)
    for (i <- 0 until numNodes) nodes(i) ! Connect(nodes((i + 1) % numNodes))
    nodes(0) ! Start
  }

  case object Start
  case object Stop
  case class Connect(next: ActorRef)
  case class Token(goal: Int)

  class RingNode(val nodeId: Int, val numMessages: Int) extends Actor {
    var nextNode: ActorRef = context.system.deadLetters
    var completed: Int = 0

    def receive = {
      case Connect(next: ActorRef) =>
        // println(s"Actor $nodeId is connecting to ${next.path}")
        nextNode = next

      case Start =>
        println("Start: \t" + Calendar.getInstance().getTime)
        BusyRing.startTime = System.currentTimeMillis()
        1 to numMessages foreach { _ =>
          nextNode ! Token(nodeId)
        }

      case Token(goal) =>
        if (goal == nodeId) {
          completed += 1
          if (completed == numMessages) {
            BusyRing.endTime = System.currentTimeMillis()
            println("Stop: \t" + Calendar.getInstance().getTime)
            println(s"Elapsed time: ${(BusyRing.endTime - BusyRing.startTime) / 1000.0}s")
            system.shutdown()
          }
        } else {
          nextNode ! Token(goal)
        }
    }
  }
}
