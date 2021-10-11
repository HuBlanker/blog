---
layout: post
category: [Java,JUC]
tags:
  - Java
  - JUC
---


## 简介

老规矩,下面是官方注释的简单翻译版本,追求速度,都不一定通顺. 谨慎阅读.

一个可复用的同步屏障，功能上类似于`CyclicBarrier`和`CountDownLatch`，但是支持更多灵活的用法.

### 登记

与其他同步屏障不同的是，`Phaser`的数量是可以各自不同的. 使用方应该使用`register`或者`bulkRegister`来进行注册.或者以构造方法的形式初始化数量。

然后在一些节点到达后可以进行取消注册.

与大多数基本的同步器构造方法一样，注册和取消注册仅影响内部计数. 他们不记录任何内部的名单，　任务无法查询他们是否已经登记了.


### 同步

和`CyclicBarrier`一样，`Phaser`支持重复调用`awaited`. `arriveAndAwaitAdvance`和`CyclicBarrier.await`的作用类似.

`Phaser`的每一代拥有一个关联的数量. Phaser的数量从零开始，所有的部分到达后，数量增加。到达int的最大值后，回归为0.

phase的数量可以独立的控制到达行为和等待行为，任何注册方可以调用一下两种方法:

* arrival

`arrive`和`arriveAndDeregister`两个方法记录到达. 这两个方法不阻塞，但是返回关联的到达阶段编号.

最后一个指定的阶段到达，　一个可选的行为会被执行，当前`phaser`结束之类的??

这些操作由触发阶段达成的最后一个触发，并由重写的`onAdvance`方法负责安排. 这个方法也负责控制终止，重写这个方法和`CyclicBarrier`的屏障行为很相似，但是更加灵活一些.

* waiting 等待

`awaitAdvance`要求一个参数，表示到达阶段的编号，或者当一个阶段前进到另一个不同的阶段时返回.
和`CyclicBarrier`的构造方法不一样,`awaitAdvance`方法继续等待,知道等待线程被中断. 可中断和带有超时的版本也是支持的. 但是超时或者中断了并不会影响Phaser的状态.

如果必要,你可以自己执行相关的恢复操作, 在调用`forceTermination`之后. 阶段还被用来执行`ForkJoinPool`.

### 终止

一个phaser将会进入终止状态, 可以使用`isTerminated`方法来检查. 如果装置了,所有的同步方法立即返回,不再等待. 返回一个负数值来表名.

相似的,在终止后尝试进行注册,也不会有反应. 当调用`onAdvance`返回true时, 终止被处罚. 如果一个取消注册的行为,让注册数量为0了, 将会终止.

### 分层

Phasers可以分层以减少竞争(比如以树状结构初始化). 设置有较大数量的Phasers将会有比较严重的同步竞争,可以使用一组子Phaser共享一个公共的负极,来避免这种情况.
浙江大大的提升吞吐量即使会导致每一个操作的浪费变大.

在一个分层phaser的树中, 子节点的注册和取消注册是自动管理的, 如果注册的数量变为非零值,子节点将注册至其父节点, 如果注册数量变为0. 子节点将从其父节点取消注册.

### monitoring 监控

因此同步方法只能由注册方进行调用,一个phaser的当前状态而已被任何调用方监控. 在一个给定的时间,`getRegisteredParties`返回总数,
`getArriveParties`返回到达的数量. `getUnarrivedParties`返回没有到达的数量. 这些方法返回值都是瞬态的,因此可能在同步控制中不是特别有用. `toString`方法返回这些状态的一个快照.


### 简单示例

Phaser可以用来替换掉`CountDownLatch`. 控制一个行为, 服务于一些部分. 通常的操作是, 设置当前线程为第一个注册者, 然后启动所有的行为,之后取消注册当前线程.

```java
void runTasks(List<Runnable> tasks) {
   Phaser startingGate = new Phaser(1); // "1" to register self
   // create and start threads
   for (Runnable task : tasks) {
     startingGate.register();
     new Thread(() -> {
       startingGate.arriveAndAwaitAdvance();
       task.run();
     }).start();
   }

   // deregister self to allow threads to proceed
   startingGate.arriveAndDeregister();
 }
```

1. 注册当前线程
2. 启动所有线程,并让他们发等待开始
3. 取消注册当前线程

让一组线程,重复执行某些行为一定的次数,可以重写`onAdvance`.

```java
 void startTasks(List<Runnable> tasks, int iterations) {
   Phaser phaser = new Phaser() {
     protected boolean onAdvance(int phase, int registeredParties) {
       return phase >= iterations - 1 || registeredParties == 0;
     }
   };
   phaser.register();
   for (Runnable task : tasks) {
     phaser.register();
     new Thread(() -> {
       do {
         task.run();
         phaser.arriveAndAwaitAdvance();
       } while (!phaser.isTerminated());
     }).start();
   }
   // allow threads to proceed; don't wait for them
   phaser.arriveAndDeregister();
 }
```

1. 初始化一个Phaser,并重写`onAdvance`.
2. 当前线程注册.
3. 如果Phaser没有终止,其他所有线程执行任务, 然后等待.
4. 当前线程取消注册,让其他线程结束.

如果主任务必须在终止后发生,他可以重复注册然后执行一个相似的循环.

```java
// ...
   phaser.register();
   while (!phaser.isTerminated())
     phaser.arriveAndAwaitAdvance();
```

如果你确定在你的上下文中,Phaser的数量不会超过int的最大值,你可以使用这些相关的构造器.

```java
 void awaitPhase(Phaser phaser, int phase) {
   int p = phaser.register(); // assumes caller not already registered
   while (p < phase) {
     if (phaser.isTerminated())
       // ... deal with unexpected termination
     else
       p = phaser.arriveAndAwaitAdvance();
   }
   phaser.arriveAndDeregister();
 }
```

## 源码阅读

由于我确实不熟悉, 所以直接按照常见顺序来学习.

### 构造方法

```java

    /**
     * Creates a new phaser with no initially registered parties, no
     * parent, and initial phase number 0. Any thread using this
     * phaser will need to first register for it.
     */
    public Phaser() {
        this(null, 0);
    }

    /**
     * Creates a new phaser with the given number of registered
     * unarrived parties, no parent, and initial phase number 0.
     *
     * @param parties the number of parties required to advance to the
     * next phase
     * @throws IllegalArgumentException if parties less than zero
     * or greater than the maximum number of parties supported
     */
    public Phaser(int parties) {
        this(null, parties);
    }

    /**
     * Equivalent to {@link #Phaser(Phaser, int) Phaser(parent, 0)}.
     *
     * @param parent the parent phaser
     */
    public Phaser(Phaser parent) {
        this(parent, 0);
    }

    /**
     * Creates a new phaser with the given parent and number of
     * registered unarrived parties.  When the given parent is non-null
     * and the given number of parties is greater than zero, this
     * child phaser is registered with its parent.
     *
     * @param parent the parent phaser
     * @param parties the number of parties required to advance to the
     * next phase
     * @throws IllegalArgumentException if parties less than zero
     * or greater than the maximum number of parties supported
     */
    public Phaser(Phaser parent, int parties) {
        // 高16位有值,异常
        if (parties >>> PARTIES_SHIFT != 0)
            throw new IllegalArgumentException("Illegal number of parties");
        // 当前阶段置为0
        int phase = 0;
        this.parent = parent;
        // 给定的父节点不为空, 是一个树形的Phaser.
        if (parent != null) {
            // 共享同一个root节点,还有所有节点共享栈
            final Phaser root = parent.root;
            this.root = root;
            this.evenQ = root.evenQ;
            this.oddQ = root.oddQ;
            // 如果参与者不为0,向当前节点的父节点,注册一个参与者,代表(当前节点需要父节点等待)
            if (parties != 0)
                phase = parent.doRegister(1);
        }
        else {
            // 父节点为空,当前是孤立的,非树形的Phaser.
            // 赋值一些属性
            this.root = this;
            this.evenQ = new AtomicReference<QNode>();
            this.oddQ = new AtomicReference<QNode>();
        }
        // 初始化状态,如果没有参与者,赋值为EMPTY=1
        // 如果有, state=高32位记录阶段号3,16-32位记录参与者数量,低16记录没有到达的数量
        this.state = (parties == 0) ? (long)EMPTY :
            ((long)phase << PHASE_SHIFT) |
            ((long)parties << PARTIES_SHIFT) |
            ((long)parties);
    }
```

共提供了4个构造方法,本质上都是调用最后一个. 详情看注释.

### 变量
    
```java
    // 内部的状态定义
    private volatile long state;

    // 一些常量
    private static final int  MAX_PARTIES     = 0xffff; // 最大参与者数量
    private static final int  MAX_PHASE       = Integer.MAX_VALUE; // 最大阶段数量
    private static final int  PARTIES_SHIFT   = 16; // 参与者占用的位数
    private static final int  PHASE_SHIFT     = 32; // 阶段占用的位数
    private static final int  UNARRIVED_MASK  = 0xffff;      // to mask ints // 掩码,计算没有到达的数量
    private static final long PARTIES_MASK    = 0xffff0000L; // to mask longs // 掩码,计算参与者的数量
    private static final long COUNTS_MASK     = 0xffffffffL; // 掩码,计数
    private static final long TERMINATION_BIT = 1L << 63; // 是否终止的bit位

    // some special values
    private static final int  ONE_ARRIVAL     = 1; // 到达的Unit值
    private static final int  ONE_PARTY       = 1 << PARTIES_SHIFT; // 一个参与者的unit值
    private static final int  ONE_DEREGISTER  = ONE_ARRIVAL|ONE_PARTY; // 一个注销.
    private static final int  EMPTY           = 1; // 空
    
    // 当前Phaser的父节点
    private final Phaser parent;

    /**
     * The root of phaser tree. Equals this if not in a tree.
     */
    // 当前Phaser的根节点.
    private final Phaser root;

    /**
     * Heads of Treiber stacks for waiting threads. To eliminate
     * contention when releasing some threads while adding others, we
     * use two of them, alternating across even and odd phases.
     * Subphasers share queues with root to speed up releases.
     */
    // 等待线程栈的头结点.
    // 根据奇偶数使用不同的Phaser.
    // 子节点共享相同的两个栈.
    private final AtomicReference<QNode> evenQ;
    private final AtomicReference<QNode> oddQ;
```

这是一些变量和常量.

* State 状态定义
* parent 父节点
* root 根节点
* evenQ 等待线程栈的偶数版本
* addQ 等待线程栈的奇数版本

其他还有一些常量,主要是用来辅助对于State的定义的,比较常见的一些shift,one等等,不再介绍.

### QNode

内部的等待节点. 定义结构比较简单, 主要是保存了当前的Phaser信息和对应的线程信息,以及一个指向下一个节点的next指针.

提供了两个方法.

#### isReleasable 是否可释放

如果内部的信息有一些不对劲, 比软线程为空,或者被中断了, 或者Phaser被别人改了,等等, 都返回true. 否则返回false. 支持中断和超时.

#### block 阻塞等待

根据是否超时, 阻塞当前线程一段时间.

```java
    static final class QNode implements ForkJoinPool.ManagedBlocker {
        // 等待的阶段
        final Phaser phaser;
        final int phase;
        final boolean interruptible;
        final boolean timed;
        boolean wasInterrupted;
        long nanos;
        final long deadline;
        volatile Thread thread; // nulled to cancel wait
        QNode next;

        QNode(Phaser phaser, int phase, boolean interruptible,
              boolean timed, long nanos) {
            this.phaser = phaser;
            this.phase = phase;
            this.interruptible = interruptible;
            this.nanos = nanos;
            this.timed = timed;
            this.deadline = timed ? System.nanoTime() + nanos : 0L;
            thread = Thread.currentThread();
        }

        public boolean isReleasable() {
            if (thread == null)
                return true;
            if (phaser.getPhase() != phase) {
                thread = null;
                return true;
            }
            if (Thread.interrupted())
                wasInterrupted = true;
            if (wasInterrupted && interruptible) {
                thread = null;
                return true;
            }
            if (timed &&
                (nanos <= 0L || (nanos = deadline - System.nanoTime()) <= 0L)) {
                thread = null;
                return true;
            }
            return false;
        }

        public boolean block() {
            while (!isReleasable()) {
                if (timed)
                    LockSupport.parkNanos(this, nanos);
                else
                    LockSupport.park(this);
            }
            return true;
        }
    }

```


### register系列

register系列提供了两个方法,`register`和`bulkRegister`两个方法,本质上都是说调用`doRegister`方法.

```java
    private int doRegister(int registrations) {
        // adjustment to state
        long adjust = ((long)registrations << PARTIES_SHIFT) | registrations;
        // 父节点
        final Phaser parent = this.parent;
        int phase;
        for (;;) {
            // 父节点为空,拿到State, 否则重新同步下State.
            long s = (parent == null) ? state : reconcileState();
            int counts = (int)s;
            // 参与者数量
            int parties = counts >>> PARTIES_SHIFT;
            // 没到达的数量
            int unarrived = counts & UNARRIVED_MASK;
            // 注册后,参与者数量超出最大值, 报错
            if (registrations > MAX_PARTIES - parties)
                throw new IllegalStateException(badRegister(s));
            // 当前所在的阶段编号
            phase = (int)(s >>> PHASE_SHIFT);
            // <0,退出
            if (phase < 0)
                break;
            // 不是第一次注册
            if (counts != EMPTY) {                  // not 1st registration
                // 没有父节点,或者同步状态已经完成
                if (parent == null || reconcileState() == s) {
                    // 
                    if (unarrived == 0)             // wait out advance
                        root.internalAwaitAdvance(phase, null);
                    else if (STATE.compareAndSet(this, s, s + adjust))
                        break;
                }
            }
            // 父节点为空, 但是是第一次注册
            else if (parent == null) {              // 1st root registration
                // 计算下一个状态值且CAS设置
                long next = ((long)phase << PHASE_SHIFT) | adjust;
                if (STATE.compareAndSet(this, s, next))
                    break;
            }
            else {
                // 是第一次注册,且是树形结构
                synchronized (this) {               // 1st sub registration
                    // 检查State
                    if (state == s) {               // recheck under lock
                        // 当前节点注册一个
                        phase = parent.doRegister(1);
                        if (phase < 0)
                            break;
                        // finish registration whenever parent registration
                        // succeeded, even when racing with termination,
                        // since these are part of the same "transaction".
                        // 注册成功
                        while (!STATE.weakCompareAndSet
                               (this, s,
                                ((long)phase << PHASE_SHIFT) | adjust)) {
                            s = state;
                            phase = (int)(root.state >>> PHASE_SHIFT);
                            // assert (int)s == EMPTY;
                        }
                        break;
                    }
                }
            }
        }
        return phase;
    }
```

主要的作用是, 根据注册的数量,更改State的值. 需要考虑是否为树形结构等来进行一些同步操作.

### arrive系列

#### arrive 和 `arriveAndDeregister` 到达,不等待其他参与者

这两个方法都实现到达相关逻辑, 调用`doArrive`来实现.

```java

    /**
     * Arrives at this phaser, without waiting for others to arrive.
     *
     * <p>It is a usage error for an unregistered party to invoke this
     * method.  However, this error may result in an {@code
     * IllegalStateException} only upon some subsequent operation on
     * this phaser, if ever.
     *
     * @return the arrival phase number, or a negative value if terminated
     * @throws IllegalStateException if not terminated and the number
     * of unarrived parties would become negative
     */
    public int arrive() {
        return doArrive(ONE_ARRIVAL);
    }

    /**
     * Arrives at this phaser and deregisters from it without waiting
     * for others to arrive. Deregistration reduces the number of
     * parties required to advance in future phases.  If this phaser
     * has a parent, and deregistration causes this phaser to have
     * zero parties, this phaser is also deregistered from its parent.
     *
     * <p>It is a usage error for an unregistered party to invoke this
     * method.  However, this error may result in an {@code
     * IllegalStateException} only upon some subsequent operation on
     * this phaser, if ever.
     *
     * @return the arrival phase number, or a negative value if terminated
     * @throws IllegalStateException if not terminated and the number
     * of registered or unarrived parties would become negative
     */
    public int arriveAndDeregister() {
        return doArrive(ONE_DEREGISTER);
    }
```

#### doArrive

```java

    /**
     * Main implementation for methods arrive and arriveAndDeregister.
     * Manually tuned to speed up and minimize race windows for the
     * common case of just decrementing unarrived field.
     *
     * @param adjust value to subtract from state;
     *               ONE_ARRIVAL for arrive,
     *               ONE_DEREGISTER for arriveAndDeregister
     */
    // arrive和arriveAAndDeregister两个方法的主要实现.
    private int doArrive(int adjust) {
        final Phaser root = this.root;
        for (;;) {
            // 如果不是树形结构,拿到State,如果是,进行一次状态同步后拿到State.
            long s = (root == this) ? state : reconcileState();
            // 当前阶段
            int phase = (int)(s >>> PHASE_SHIFT);
            if (phase < 0) // 阶段小于0,直接退出
                return phase;
            int counts = (int)s; // 这个s是高16位是参与者数量,低16位是未到达数量, 整合的一个数字
            // 没有到达的数量
            int unarrived = (counts == EMPTY) ? 0 : (counts & UNARRIVED_MASK);
            if (unarrived <= 0)
                throw new IllegalStateException(badArrive(s));
            // 到达成功, 更改State成功.
            if (STATE.compareAndSet(this, s, s-=adjust)) {
                // 只有一个未到达的了
                if (unarrived == 1) {
                    // 参数者数量
                    long n = s & PARTIES_MASK;  // base of next state
                    // 
                    int nextUnarrived = (int)n >>> PARTIES_SHIFT;
                    
                    // 不是树形结构
                    if (root == this) {
                        // 如果需要终止, 就终止
                        if (onAdvance(phase, nextUnarrived))
                            n |= TERMINATION_BIT;
                        // 
                        else if (nextUnarrived == 0)
                            n |= EMPTY;
                        else
                            n |= nextUnarrived;
                        // 下一个阶段编号
                        int nextPhase = (phase + 1) & MAX_PHASE;
                        // 计算新的State并写入
                        n |= (long)nextPhase << PHASE_SHIFT;
                        STATE.compareAndSet(this, s, n);
                        // 释放等待的
                        releaseWaiters(phase);
                    }
                    // 树形结构, 父节点进行到达行为, 然后当前节点跟进状态
                    else if (nextUnarrived == 0) { // propagate deregistration
                        phase = parent.doArrive(ONE_DEREGISTER);
                        STATE.compareAndSet(this, s, s | EMPTY);
                    }
                    else
                        phase = parent.doArrive(ONE_ARRIVAL);
                }
                return phase;
            }
        }
    }

```

主要作用是对State中的未到达数量进行递减,之后根据是否完全到达,是否是树形结构, 做一些对应的操作.

#### arriveAndAwaitAdvance 到达然后等待其他参与者

```java

    /**
     * Arrives at this phaser and awaits others. Equivalent in effect
     * to {@code awaitAdvance(arrive())}.  If you need to await with
     * interruption or timeout, you can arrange this with an analogous
     * construction using one of the other forms of the {@code
     * awaitAdvance} method.  If instead you need to deregister upon
     * arrival, use {@code awaitAdvance(arriveAndDeregister())}.
     *
     * <p>It is a usage error for an unregistered party to invoke this
     * method.  However, this error may result in an {@code
     * IllegalStateException} only upon some subsequent operation on
     * this phaser, if ever.
     *
     * @return the arrival phase number, or the (negative)
     * {@linkplain #getPhase() current phase} if terminated
     * @throws IllegalStateException if not terminated and the number
     * of unarrived parties would become negative
     */
    // 到达并等待其他参与者,等价于调用`awaitAdvance(arrive())`.
    
    public int arriveAndAwaitAdvance() {
        // Specialization of doArrive+awaitAdvance eliminating some reads/paths
        final Phaser root = this.root;
        for (;;) {
            // 这块和之前逻辑一样
            long s = (root == this) ? state : reconcileState();
            int phase = (int)(s >>> PHASE_SHIFT);
            if (phase < 0)
                return phase;
            int counts = (int)s;
            int unarrived = (counts == EMPTY) ? 0 : (counts & UNARRIVED_MASK);
            if (unarrived <= 0)
                throw new IllegalStateException(badArrive(s));
            // 到达一个更新State成功
            if (STATE.compareAndSet(this, s, s -= ONE_ARRIVAL)) {
                if (unarrived > 1)
                    return root.internalAwaitAdvance(phase, null);
                // 父节点到达
                if (root != this)
                    return parent.arriveAndAwaitAdvance();
                long n = s & PARTIES_MASK;  // base of next state
                int nextUnarrived = (int)n >>> PARTIES_SHIFT;
                if (onAdvance(phase, nextUnarrived))
                    n |= TERMINATION_BIT;
                else if (nextUnarrived == 0)
                    n |= EMPTY;
                else
                    n |= nextUnarrived;
                int nextPhase = (phase + 1) & MAX_PHASE;
                n |= (long)nextPhase << PHASE_SHIFT;
                if (!STATE.compareAndSet(this, s, n))
                    return (int)(state >>> PHASE_SHIFT); // terminated
                releaseWaiters(phase);
                return nextPhase;
            }
        }
    }
```

等价于`awaitAdvance(arrive()))`.

### await系列

 awaitAdvance, awaitAdvanceInterruptibly, awaitAdvanceInterruptibly 三个await系列的方法,本质上都是调用的
 父节点的`internalAwaitAdvance`. 只是支持了中断和超时而已.

```java
    /**
     * Awaits the phase of this phaser to advance from the given phase
     * value, returning immediately if the current phase is not equal
     * to the given phase value or this phaser is terminated.
     *
     * @param phase an arrival phase number, or negative value if
     * terminated; this argument is normally the value returned by a
     * previous call to {@code arrive} or {@code arriveAndDeregister}.
     * @return the next arrival phase number, or the argument if it is
     * negative, or the (negative) {@linkplain #getPhase() current phase}
     * if terminated
     */
    // 等待阶段升级
    // 如果给定的阶段和当前不一致,或者当前Phaser终止了,直接返回.
    public int awaitAdvance(int phase) {
        final Phaser root = this.root;
        // 拿到Staate.
        long s = (root == this) ? state : reconcileState();
        // 当前的阶段
        int p = (int)(s >>> PHASE_SHIFT);
        if (phase < 0)
            return phase;
        // 如果一样,等待父节点升级,
        if (p == phase)
            return root.internalAwaitAdvance(phase, null);
        return p;
    }
    
    

    /**
     * Possibly blocks and waits for phase to advance unless aborted.
     * Call only on root phaser.
     *
     * @param phase current phase
     * @param node if non-null, the wait node to track interrupt and timeout;
     * if null, denotes noninterruptible wait
     * @return current phase
     */
    // 只有跟节点调用,可能会阻塞
    private int internalAwaitAdvance(int phase, QNode node) {
        // assert root == this;
        // 释放等待者
        releaseWaiters(phase-1);          // ensure old queue clean
        boolean queued = false;           // true when node is enqueued
        int lastUnarrived = 0;            // to increase spins upon change
        int spins = SPINS_PER_ARRIVAL;
        long s;
        int p;
        // 当给定的阶段和当前阶段一致时
        while ((p = (int)((s = state) >>> PHASE_SHIFT)) == phase) {
            // 节点为空,
            if (node == null) {           // spinning in noninterruptible mode
                // 计算自旋次数
                int unarrived = (int)s & UNARRIVED_MASK;
                if (unarrived != lastUnarrived &&
                    (lastUnarrived = unarrived) < NCPU)
                    spins += SPINS_PER_ARRIVAL;
                boolean interrupted = Thread.interrupted();
                // 自旋为0或者线程中断了,创建一个节点
                if (interrupted || --spins < 0) { // need node to record intr
                    node = new QNode(this, phase, false, false, 0L);
                    node.wasInterrupted = interrupted;
                }
                else
                    // 休眠等待
                    Thread.onSpinWait();
            }
            else if (node.isReleasable()) // done or aborted
                break;
            else if (!queued) {           // push onto queue
                // 入栈
                AtomicReference<QNode> head = (phase & 1) == 0 ? evenQ : oddQ;
                QNode q = node.next = head.get();
                if ((q == null || q.phase == phase) &&
                    (int)(state >>> PHASE_SHIFT) == phase) // avoid stale enq
                    queued = head.compareAndSet(q, node);
            }
            else {
                try {
                    ForkJoinPool.managedBlock(node);
                } catch (InterruptedException cantHappen) {
                    node.wasInterrupted = true;
                }
            }
        }

        if (node != null) {
            if (node.thread != null)
                node.thread = null;       // avoid need for unpark()
            if (node.wasInterrupted && !node.interruptible)
                Thread.currentThread().interrupt();
            if (p == phase && (p = (int)(state >>> PHASE_SHIFT)) == phase)
                return abortWait(phase); // possibly clean up on abort
        }
        releaseWaiters(phase);
        return p;
    }
```


### 强行终止

```java
    /**
     * Forces this phaser to enter termination state.  Counts of
     * registered parties are unaffected.  If this phaser is a member
     * of a tiered set of phasers, then all of the phasers in the set
     * are terminated.  If this phaser is already terminated, this
     * method has no effect.  This method may be useful for
     * coordinating recovery after one or more tasks encounter
     * unexpected exceptions.
     */
    public void forceTermination() {
        // Only need to change root state
        final Phaser root = this.root;
        long s;
        while ((s = root.state) >= 0) {
            if (STATE.compareAndSet(root, s, s | TERMINATION_BIT)) {
                // signal all threads
                releaseWaiters(0); // Waiters on evenQ
                releaseWaiters(1); // Waiters on oddQ
                return;
            }
        }
    }
```


比较简单, 只要根节点的状态不为0,就强行设置为终止了. 释放所有的等待节点.

### onAdvance

这是预留给子类的一个方法, 可以定义Phaser升级时执行的动作,还可以定义锁是否要升级. 默认实现是注册的参与者为0, 就终止整个Phaser.




### 监控方法

还有很多负责监控当前Phaser状态 的方法,这里简单记录一下 .

* getPhase 拿到阶段编号
* getRegisteredParites  拿到当前的参与者数量
* getArrivedParties 拿到当前到达的参与者数量
* getUnarrivedParties 未到达的参与者数量 
* getParent 返回当前节点的父节点
* getRoot 获取根节点
* isTerminated 是否被终止


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