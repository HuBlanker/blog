java.util.concurrent. JDK中提供的一个并发工具包.比较重要，对于理解并发也有帮助.

这个章节学习一下相关的源码.


![juc脑图](http://img.couplecoders.tech/JUC.png)

juc包下, 包含以下内容:

* atomic原子类: 
主要包含Integer,Long,Boolean,Double,Array等.  

* lock及同步器:
  * AQS
      * CountDownLatch
      * CyclicBarrier
      * Semaphore
      * ReentrantLock
      * ReentrantReadWriteLock
  * StampedLock
  * Phaser
  * Exchanger
  * condition

* 线程池


一些同步的集合.

ArrayBlockingQueue
BlockingDeque
BlockingQueue
ConcurrentHashMap
ConcurrentLinkedDeque
ConcurrentLinkedQueue
ConcurrentMap
ConcurrentNavigableMap
ConcurrentSkipListMap
ConcurrentSkipListSet
CopyOnWriteArrayList
CopyOnWriteArraySet
Delayed
DelayQueue
LinkedBlockingDeque
LinkedBlockingQueue
LinkedTransferQueue
PriorityBlockingQueue
SynchronousQueue
ThreadLocalRandom
TransferQueue

# Flow等发布订阅系列

SubmissionPublisher
Flow

# threadLocalRandom


