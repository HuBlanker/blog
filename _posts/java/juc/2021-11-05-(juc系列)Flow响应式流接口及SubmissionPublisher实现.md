---
layout: post
category: [Java,JUC, Flow,SubmissionPublisher]
tags:
  - Java
  - SubmissionPublisher
  - JUC
  - Flow
---

## 前言

## Flow 

### 官方注释翻译


一些接口和静态方法，为了建立流式组件, `Publisher`生成元素，被一个或者多个`Subscriber`消费，每一个`Subscriber`被`Subscription`管理.

接口介绍: [reactive-streams](http://www.reactive-streams.org/). 他们适用于并发和分布式的环境. 所有的方法都定义为吴晓的单向消息风格.

通信依赖于一个流的简单形式控制. 他可以用来避免在`push`类型的系统中的资源管理问题.

示例:

一个`Flow.Publisher`通常定义了他自己的`Subscription`实现，在`subscribe`方法中创建一个，然后叫他交给`Flow.Subscriber`。

桶异步的发布消息，通常使用一个线程池. 下面是一个简单的发布者，仅仅发布一个`TRUE`给单个的订阅者. 因为订阅者只收到一个简单的元素，这个类不需要使用缓冲以及
顺序控制.

```java
 class OneShotPublisher implements Publisher<Boolean> {
    //线程池
   private final ExecutorService executor = ForkJoinPool.commonPool(); // daemon-based
    // 是否被订阅,因为这个发布者只能被一个人订阅
   private boolean subscribed; // true after first subscribe
    // 订阅方法
   public synchronized void subscribe(Subscriber<? super Boolean> subscriber) {
     if (subscribed)
       subscriber.onError(new IllegalStateException()); // only one allowed
     else {
         // 订阅成功
       subscribed = true;
       subscriber.onSubscribe(new OneShotSubscription(subscriber, executor));
     }
   }
   // 订阅管理
   static class OneShotSubscription implements Subscription {
       // 订阅者
     private final Subscriber<? super Boolean> subscriber;
     // 线程池
     private final ExecutorService executor;
     // 结果
     private Future<?> future; // to allow cancellation
       // 是否完成
     private boolean completed;
     // 构造方法
     OneShotSubscription(Subscriber<? super Boolean> subscriber,
                         ExecutorService executor) {
       this.subscriber = subscriber;
       this.executor = executor;
     }
     // request
     public synchronized void request(long n) {
         // 没有完成
       if (!completed) {
         completed = true;
         if (n <= 0) {
           IllegalArgumentException ex = new IllegalArgumentException();
           executor.execute(() -> subscriber.onError(ex));
         } else {
             // 执行方法
           future = executor.submit(() -> {
             subscriber.onNext(Boolean.TRUE);
             subscriber.onComplete();
           });
         }
       }
     }
     // 取消
     public synchronized void cancel() {
       completed = true;
       if (future != null) future.cancel(false);
     }
   }
 }
```

这是一个很简单的应用场景，单个的发布者发布消息给单个的消费者. 

一个`Flow.Subscriber`安排元素的请求和处理. 元素在调用`request`之前不会被发布, 但是多个元素可能被`request`. 

很多`Subscriber`的实现可以按照下面这种风格管理元素，缓冲区大小通常为1个单步，更大的缓冲区大小通常允许更加高效的重叠处理. 同时进行更少的通信.

比如给定数量为64，则未完成的请求总数将保持在32-64之间. 因为`Subscriber`方法的调用是严格有序的，不需要这些方法使用锁或者`volatile`除非订阅服务器维护了多个订阅.

```java
 class SampleSubscriber<T> implements Subscriber<T> {
   final Consumer<? super T> consumer;
   Subscription subscription;
   final long bufferSize;
   long count;
   SampleSubscriber(long bufferSize, Consumer<? super T> consumer) {
     this.bufferSize = bufferSize;
     this.consumer = consumer;
   }
   
   public void onSubscribe(Subscription subscription) {
     long initialRequestSize = bufferSize;
     count = bufferSize - bufferSize / 2; // re-request when half consumed
     (this.subscription = subscription).request(initialRequestSize);
   }
   public void onNext(T item) {
     if (--count <= 0)
       subscription.request(count = bufferSize - bufferSize / 2);
     consumer.accept(item);
   }
   public void onError(Throwable ex) { ex.printStackTrace(); }
   public void onComplete() {}
 }
```

`defaultBufferSize`的默认值通常提供一个有用的七点，用于根据预期的速率，资源使用情况选择Flow组件中的请求大小和容量. 或者，当不需要使用流式控制时，订阅者可以初始化无界的队列集合.


```java
 class UnboundedSubscriber<T> implements Subscriber<T> {
   public void onSubscribe(Subscription subscription) {
     subscription.request(Long.MAX_VALUE); // effectively unbounded
   }
   public void onNext(T item) { use(item); }
   public void onError(Throwable ex) { ex.printStackTrace(); }
   public void onComplete() {}
   void use(T item) { ... }
 }
```

### 源码

#### Publisher 发布者

```java
    public static interface Publisher<T> {
        public void subscribe(Subscriber<? super T> subscriber);
    }
```

定义了向`Publisher`中添加一个订阅者.


#### Subscriber 订阅者

```java

    public static interface Subscriber<T> {
        public void onSubscribe(Subscription subscription);

        public void onNext(T item);

        public void onError(Throwable throwable);

        public void onComplete();
    }
```

订阅者的接口，分别定义了:

* onSubscribe  添加一个订阅 TODO 不对
* onNext 处理一个元素
* onError 出错
* onComplete 完成

#### Subscription 订阅

发布者和订阅者之间链接的消息管理器. 

```java

    public static interface Subscription {
        /**
         * Adds the given number {@code n} of items to the current
         * unfulfilled demand for this subscription.  If {@code n} is
         * less than or equal to zero, the Subscriber will receive an
         * {@code onError} signal with an {@link
         * IllegalArgumentException} argument.  Otherwise, the
         * Subscriber will receive up to {@code n} additional {@code
         * onNext} invocations (or fewer if terminated).
         *
         * @param n the increment of demand; a value of {@code
         * Long.MAX_VALUE} may be considered as effectively unbounded
         */
        public void request(long n);

        /**
         * Causes the Subscriber to (eventually) stop receiving
         * messages.  Implementation is best-effort -- additional
         * messages may be received after invoking this method.
         * A cancelled subscription need not ever receive an
         * {@code onComplete} or {@code onError} signal.
         */
        public void cancel();
    }

```

* request 添加给定数量的元素
* cancel 取消

#### Processor 

同时实现了生产者和消费者的一个组件类~.

## SubmissionPublisher

### 官方注释翻译

一个`Flow.Publisher`, 异步的提交非空元素给他的订阅者，知道订阅者关闭. 每一个订阅者按照相同的顺序，接受新提交的元素.除非遇到异常.
`SubmissionPublisher`允许元素生成以兼容`reactive-streams`, 发布者依赖于dop或者阻塞来进行流的控制.

`SubmissionPublisher`使用线程池提交给他的订阅者. 线程池的选择根据它的使用场. 

如果提交的元素在独立的线程中运行，且订阅者的数量可以预估， 那可以使用`Executors.newFixedThreadPool`. 否则的话， 默认使用的是`ForkJoinPoll.commonPool`.

缓冲区允许生产者和消费者暂时性的以不同的速率运行. 每个订阅者使用独立的缓冲区. 缓冲区在第一次使用时重建以及根据需要进行扩容. 

`request`的调用不直接导致缓冲区的扩容. 但是如果为填充的请求超过最大容量，则有饱和的风险. `Flow.defaultBufferSize`提供了一个容量的七点，基于期望的速度，资源和使用情况.

发布方法支持关于缓冲区饱和时的不同策略. `submit`代码阻塞知道资源可用. 这是最简单的策略，但是最慢. `offer  `方法可能丢弃元素，但是提供了插入处理然后重试的机会.

如果一些订阅者的方法抛出异常了，他的订阅会被取消. 如果在构造方法中提交了一个`handler`， 
`onNext`方法如果发生了异常，会调用该处理方法，但是`onSubscribe``OnError`和`OnComplete`方法是不记录和处理异常的. 

如果提交到线程池发生了`RejectedExecutionException`或者其他的一些运行时异常,或者一个丢弃处理器抛出了一个异常.不是全部的订阅者能够接收到发布的元素.

`consume`方法简化了对一些常见情况的支持，在这种情况下，订阅者的唯一操作是使用提供的函数请求和处理所有项.

这个类还可以作为生成项的子类的一个基础，并使用这个类中的方法来发布他们。 比如:

这里有一个周期性发布发布元素的类.(实际上，您可以添加方法来独立的启动和停止，在发布者之间共享线程池等等，或者使用`SubmissionPublisher`作为一个组件而不是超类.)


```java
 class PeriodicPublisher<T> extends SubmissionPublisher<T> {
    // 周期任务
    final ScheduledFuture<?> periodicTask;
    // 线程池
    final ScheduledExecutorService scheduler;

    PeriodicPublisher(Executor executor, int maxBufferCapacity,
                      Supplier<? extends T> supplier,
                      long period, TimeUnit unit) {
        super(executor, maxBufferCapacity);
        scheduler = new ScheduledThreadPoolExecutor(1);
        periodicTask = scheduler.scheduleAtFixedRate(
                () -> submit(supplier.get()), 0, period, unit);
    }

    public void close() {
        periodicTask.cancel(false);
        scheduler.shutdown();
        super.close();
    }
}
```

这里有一个`Flow.Processor`的实现例子. 它使用单步请求他的发布者， 适应性更强的版本可以使用提交返回的延迟及其他方法来监控流.

```java
 class TransformProcessor<S,T> extends SubmissionPublisher<T>
   implements Flow.Processor<S,T> {
   final Function<? super S, ? extends T> function;
   Flow.Subscription subscription;
   TransformProcessor(Executor executor, int maxBufferCapacity,
                      Function<? super S, ? extends T> function) {
     super(executor, maxBufferCapacity);
     this.function = function;
   }
   public void onSubscribe(Flow.Subscription subscription) {
     (this.subscription = subscription).request(1);
   }
   public void onNext(S item) {
     subscription.request(1);
     submit(function.apply(item));
   }
   public void onError(Throwable ex) { closeExceptionally(ex); }
   public void onComplete() { close(); }
 }
```


简直晦涩难懂。。。翻译之后更加难懂了.


这里强烈推荐下这篇文章，我看完清晰了许多: 

[Java9 reactive stream](https://www.cnblogs.com/IcanFixIt/p/7245377.html)

### 源码简介

#### SubmissionPublisher 发布者功能

这个类也是最外层的类. 

##### 属性

```java

    // 订阅者的链表
    BufferedSubscription<T> clients;

    // 是否已经关闭
    volatile boolean closed;
    // 导致关闭的异常
    volatile Throwable closedException;

    // 线程池
    final Executor executor;
    // handler 处理器
    final BiConsumer<? super Subscriber<? super T>, ? super Throwable> onNextHandler;
    // 最大缓冲区的容量
    final int maxBufferCapacity;

```

一个发布者可以被多个订阅者订阅，这些订阅者使用一个链表进行保存. 此外记录了当前发布者的一些状态，具体在注释里.


##### 构造方法

```java

    public SubmissionPublisher(Executor executor, int maxBufferCapacity,
                               BiConsumer<? super Subscriber<? super T>, ? super Throwable> handler) {
        if (executor == null)
            throw new NullPointerException();
        if (maxBufferCapacity <= 0)
            throw new IllegalArgumentException("capacity must be positive");
        this.executor = executor;
        this.onNextHandler = handler;
        this.maxBufferCapacity = roundCapacity(maxBufferCapacity);
    }

    public SubmissionPublisher(Executor executor, int maxBufferCapacity) {
        this(executor, maxBufferCapacity, null);
    }

    public SubmissionPublisher() {
        this(ASYNC_POOL, Flow.defaultBufferSize(), null);
    }
```
进行参数校验后进行赋值操作.

##### subscribe 订阅方法

这是作为发布者接口的实现方法. 

```java

    public void subscribe(Subscriber<? super T> subscriber) {
        if (subscriber == null) throw new NullPointerException();
        int max = maxBufferCapacity; // allocate initial array
        Object[] array = new Object[max < INITIAL_CAPACITY ?
                                    max : INITIAL_CAPACITY];
        // 创建订阅令牌
        BufferedSubscription<T> subscription =
            new BufferedSubscription<T>(subscriber, executor, onNextHandler,
                                        array, max);
        // 加锁执行
        synchronized (this) {
            // 记录第一个订阅者的线程
            if (!subscribed) {
                subscribed = true;
                owner = Thread.currentThread();
            }
            for (BufferedSubscription<T> b = clients, pred = null;;) {
                // 当前订阅者是第一个
                if (b == null) {
                    Throwable ex;
                    subscription.onSubscribe();
                    if ((ex = closedException) != null)
                        subscription.onError(ex);
                    else if (closed)
                        subscription.onComplete();
                    else if (pred == null)
                        clients = subscription;
                    else
                        pred.next = subscription;
                    break;
                }
                // 链接到后面
                BufferedSubscription<T> next = b.next;
                if (b.isClosed()) {   // remove
                    b.next = null;    // detach
                    if (pred == null)
                        clients = next;
                    else
                        pred.next = next;
                }
                else if (subscriber.equals(b.subscriber)) {
                    b.onError(new IllegalStateException("Duplicate subscribe"));
                    break;
                }
                else
                    pred = b;
                b = next;
            }
        }
    }
```

1. 首先根据当前的订阅者构造订阅令牌
2. 找到链表的尾部，将当前订阅者插入
3. 之后调用订阅令牌的`OnSubscribe`方法. **稍后联系订阅者及令牌的代码一起看**.

##### submit 提交元素 由发布者发布

```java

    public int submit(T item) {
        return doOffer(item, Long.MAX_VALUE, null);
    }

    private int doOffer(T item, long nanos,
                        BiPredicate<Subscriber<? super T>, ? super T> onDrop) {
        if (item == null) throw new NullPointerException();
        int lag = 0;
        boolean complete, unowned;
        synchronized (this) {
            Thread t = Thread.currentThread(), o;
            BufferedSubscription<T> b = clients;
            if ((unowned = ((o = owner) != t)) && o != null)
                owner = null;                     // disable bias
            if (b == null)
                complete = closed;
            else {
                complete = false;
                boolean cleanMe = false;
                BufferedSubscription<T> retries = null, rtail = null, next;
                // 循环调用令牌的offer方法，进行发布消息.
                do {
                    next = b.next;
                    int stat = b.offer(item, unowned);
                    if (stat == 0) {              // saturated; add to retry list
                        b.nextRetry = null;       // avoid garbage on exceptions
                        if (rtail == null)
                            retries = b;
                        else
                            rtail.nextRetry = b;
                        rtail = b;
                    }
                    else if (stat < 0)            // closed
                        cleanMe = true;           // remove later
                    else if (stat > lag)
                        lag = stat;
                } while ((b = next) != null);

                if (retries != null || cleanMe)
                    lag = retryOffer(item, nanos, onDrop, retries, lag, cleanMe);
            }
        }
        if (complete)
            throw new IllegalStateException("Closed");
        else
            return lag;
    }

```

#### ConsumerSubscriber 订阅者实现

```java

    static final class ConsumerSubscriber<T> implements Subscriber<T> {
        final CompletableFuture<Void> status;
        final Consumer<? super T> consumer;
        Subscription subscription;
        // 保存Consumer, 以及状态，令牌
        ConsumerSubscriber(CompletableFuture<Void> status,
                           Consumer<? super T> consumer) {
            this.status = status; this.consumer = consumer;
        }
        // 由发布者，将令牌给回订阅者
        public final void onSubscribe(Subscription subscription) {
            this.subscription = subscription;
            status.whenComplete((v, e) -> subscription.cancel());
            if (!status.isDone())
                subscription.request(Long.MAX_VALUE);
        }
        // 错误处理
        public final void onError(Throwable ex) {
            status.completeExceptionally(ex);
        }
        // 完成
        public final void onComplete() {
            status.complete(null);
        }
        // 处理下一个元素,即Consumer执行
        public final void onNext(T item) {
            try {
                consumer.accept(item);
            } catch (Throwable ex) {
                subscription.cancel();
                status.completeExceptionally(ex);
            }
        }
    }
```

这个类比较简单，因为没有设计具体的业务实现，只是实现了接受令牌，处理错误，完成，以及在每次接收到发布者发的消息之后，调用初始化时的Consumer进行消费即可》


####  BufferedSubscription 订阅令牌实现

```java

        long timeout;                      // Long.MAX_VALUE if untimed wait
        int head;                          // next position to take
        int tail;                          // next position to put
        final int maxCapacity;             // max buffer size
        volatile int ctl;                  // atomic run state flags
        Object[] array;                    // buffer
        final Subscriber<? super T> subscriber;
        final BiConsumer<? super Subscriber<? super T>, ? super Throwable> onNextHandler;
        Executor executor;                 // null on error
        Thread waiter;                     // blocked producer thread
        Throwable pendingError;            // holds until onError issued
        BufferedSubscription<T> next;      // used only by publisher
        BufferedSubscription<T> nextRetry; // used only by publisher

        @jdk.internal.vm.annotation.Contended("c") // segregate
        volatile long demand;              // # unfilled requests
        @jdk.internal.vm.annotation.Contended("c")
        volatile int waiting;              // nonzero if producer blocked

        // ctl bit values
        static final int CLOSED   = 0x01;  // if set, other bits ignored
        static final int ACTIVE   = 0x02;  // keep-alive for consumer task
        static final int REQS     = 0x04;  // (possibly) nonzero demand
        static final int ERROR    = 0x08;  // issues onError when noticed
        static final int COMPLETE = 0x10;  // issues onComplete when done
        static final int RUN      = 0x20;  // task is or will be running
        static final int OPEN     = 0x40;  // true after subscribe

        static final long INTERRUPTED = -1L; // timeout vs interrupt sentinel
```

这个实际上就是发布者中保存的订阅实现，是链表节点.

* array 保存了当前订阅令牌中的消息
* next 实现了链表节点的下一个节点指针

#####  offer 接受消息

在发布者中，消息通过内部链表节点的offer来进行发布，也就是这里了.

```java
        // 将元素写入到数组中
        final int offer(T item, boolean unowned) {
            Object[] a;
            int stat = 0, cap = ((a = array) == null) ? 0 : a.length;
            int t = tail, i = t & (cap - 1), n = t + 1 - head;
            if (cap > 0) {
                boolean added;
                if (n >= cap && cap < maxCapacity) // resize
                    added = growAndOffer(item, a, t);
                else if (n >= cap || unowned)      // need volatile CAS
                    added = QA.compareAndSet(a, i, null, item);
                else {                             // can use release mode
                    QA.setRelease(a, i, item);
                    added = true;
                }
                if (added) {
                    tail = t + 1;
                    stat = n;
                }
            }
            return startOnOffer(stat);
        }
        // 元素入队后，尝试启动一个任务消费
        final int startOnOffer(int stat) {
            int c; // start or keep alive if requests exist and not active
            if (((c = ctl) & (REQS | ACTIVE)) == REQS &&
                ((c = getAndBitwiseOrCtl(RUN | ACTIVE)) & (RUN | CLOSED)) == 0)
                tryStart();
            else if ((c & CLOSED) != 0)
                stat = -1;
            return stat;
        }

         // 尝试启动一个任务，调用当前的consumer方法
        final void tryStart() {
            try {
                Executor e;
                ConsumerTask<T> task = new ConsumerTask<T>(this);
                if ((e = executor) != null)   // skip if disabled on error
                    e.execute(task);
            } catch (RuntimeException | Error ex) {
                getAndBitwiseOrCtl(ERROR | CLOSED);
                throw ex;
            }
        }
```


### 总结

比较复杂，没有认真看代码，主要是了解一下大体上的实现即可.

SubmissionPublisher实现了`Flow`类中定义的接口，提供了一套响应式的API. 其调用链大概是: 

*注意，全是异步操作*

1. `Subscriber`向`Publisher`注册自己，调用`Publisher.subscribe()`.
2. `Publisher`接受注册，生成令牌，返回给`Subscriber`, 调用`Subscriber.onSubscribe()`.
3. `Subscriber`通过令牌`Subscription.request()`，告诉`Publisher`自己需要多少消息(注意，这一步可以一次性告知最大值，也可以分批次告知).
3. 程序通过`Publisher.submit()`发布一条消息，`Publisher`通过内部保存的`Subscription`链表，逐个调用他们的`offer`方法. 需要考虑每个订阅者需要的消息数量
4. `Subscription`根据自己的策略，是否缓冲等，启动任务，任务中调用`Subscriber.onNext`执行方法.



## 参考文章


<br>


完。
<br>
<br>
<br>


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)


<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**