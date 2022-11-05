---
layout: post
tags:
  - Java
  - JUC
---


本文源码基于: <font color='red'>JDK13</font>

## 简介

老规矩,下面是官方注释的简单翻译版本,追求速度,都不一定通顺. 谨慎阅读.

一个可复用的同步屏障，功能上类似于`CyclicBarrier`和`CountDownLatch`，但是支持更多灵活的用法.

### 登记

与其他同步屏障不同的是，`Phaser`的数量是可以各自不同的. 使用方应该使用`register`或者`bulkRegister`来进行注册.或者以构造方法的形式初始化数量。 然后在一些节点到达后可以进行取消注册.

与大多数基本的同步器构造方法一样，注册和取消注册仅影响内部计数. 他们不记录任何内部的名单，　任务无法查询他们是否已经登记了.

`CountDownLatch`和`CyclicBarrier`,`Semaphore`等等都是指定数量后不能变化的，而`Phaser`的注册数量是可以随时变化的，因此更加灵活.

### 同步

和`CyclicBarrier`一样，`Phaser`支持重复调用`awaited`. `arriveAndAwaitAdvance`和`CyclicBarrier.await`的作用类似.

`Phaser`的每一代拥有一个关联的编号. Phaser的阶段编号从零开始，所有的参与者到达后，阶段编号增加。到达int的最大值后，回归为0.

阶段编号可以独立的控制到达行为和等待行为，任何注册方可以调用以下两种方法:

* arrival

`arrive`和`arriveAndDeregister`两个方法记录到达. 这两个方法不阻塞，但是返回关联的到达阶段编号.

指定阶段编号的最后一个参与者到达，一个可选的行为会被执行，然后Phaser进行升级.

这两个操作由`触发阶段升级的最后一个参与者触发`，并由重写的`onAdvance`方法负责控制. 这个方法也负责控制终止，
重写这个方法和`CyclicBarrier`的屏障行为很相似，但是更加灵活一些.

* waiting 等待

`awaitAdvance`要求一个参数，表示到达阶段的编号，或者当一个阶段升级到另一个不同的阶段时返回.
和`CyclicBarrier`的方法不一样,`awaitAdvance`方法继续等待,直到等待线程被中断. 可中断和带有超时的版本也是支持的. 但是超时或者中断了并不会影响Phaser的状态.

如果必要,你可以自己执行相关的恢复操作, 在调用`forceTermination`之后. 阶段还被用来执行`ForkJoinPool`.

### 终止

一个phaser可以进入终止状态, 使用`isTerminated`方法来检查. 如果终止了,所有的同步方法立即返回,不再等待. 返回一个负数值来表名这点.

相似的,在终止后尝试进行注册,也不会有反应. 当调用`onAdvance`返回true时, 终止被触发. 
如果一个取消注册的行为,让注册数量为0了, 将会终止.

### 分层

Phasers可以分层以减少竞争(比如以树状结构初始化). 设置有较大数量的Phasers将会有比较严重的同步竞争,可以使用一组子Phaser共享一个公共的父节点,
来避免这种情况. 这将大大的提升吞吐量即使会导致每一个操作的浪费变大.

在一个分层phaser的树中, 子节点的注册和取消注册是自动管理的, 如果注册的数量变为非零值,子节点将注册至其父节点, 如果注册数量变为0. 子节点将从其父节点取消注册.

可以查看下方分层的示例来了解.

因为支持分层，因此一个Phaser有三种形态.

* 非树形，单个节点

这是最简单的形态，只要自身的注册数等于到达数，就升级一次阶段编号即可.

* 树形，叶子节点

只要自身的注册数量等于到达数量，就代表自己这个节点“到达”了，向父节点的到达数+1.

* 树形，非叶子节点

自身到达数等于注册数，这里的到达数不是参与的任务数，而是自己的子节点的数量，自己的所有子节点全部到达，自己才算到达，向自己的父节点进行"到达"操作。
如果这个节点是根节点，那么整个Phaser树才算是全部到达，进行升级操作.

### monitoring 监控

即使同步方法只能由注册方进行调用,一个phaser的当前状态可以被任何调用方监控. 在一个给定的时间,`getRegisteredParties`返回总数,
`getArriveParties`返回到达的数量. `getUnarrivedParties`返回没有到达的数量. 这些方法返回值都是瞬态的,因此可能在同步控制中不是特别有用. `toString`方法返回这些状态的一个快照.

### 简单示例

#### 代替`CountDownLatch`

Phaser可以用来替换掉`CountDownLatch`. 控制一个行为, 服务于一些部分. 
通常的操作是, 设置当前线程为第一个注册者, 然后启动所有的行为,之后取消注册当前线程.

```java
void runTasks(List<Runnable> tasks) { 
   // 此时注册数量为1
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

1. 注册当前线程(此时注册数量为1)
2. 启动所有线程,首先注册一次(全部完成后，此时注册数量为`tasks.size() + 1) ，之后让他们`arriveAndAwaitAdvance`. 到达并且等待升级(此时到达数量为`tasks.size()`.
3. 取消注册当前线程(注册数量变成`tasks.size()`), Phaser的注册数量等于到达数量。因此进行升级，所有等待的线程唤醒，继续执行任务. 

#### 重复执行一组任务指定次数

让一组线程,重复执行某些行为一定的次数,可以重写`onAdvance`.

```java
 void startTasks(List<Runnable> tasks, int iterations) {
   Phaser phaser = new Phaser() {
       // 终止条件, 阶段编号大于等于给定循环次数减1. 其实就是只能循环给定次数
     protected boolean onAdvance(int phase, int registeredParties) {
       return phase >= iterations - 1 || registeredParties == 0;
     }
   };
   // 注册一个
   phaser.register();
   for (Runnable task : tasks) {
     // 注册`tasks.size()`个
     phaser.register();
     new Thread(() -> {
       do {
         task.run();
         // 等待升级
         phaser.arriveAndAwaitAdvance();
       } while (!phaser.isTerminated());
     }).start();
   }
   // allow threads to proceed; don't wait for them
   // 取消注册，开始所有任务
   phaser.arriveAndDeregister();
 }
```

1. 初始化一个Phaser,并重写`onAdvance`. 让阶段编号大于给定次数时，Phaser进行终止.
2. 当前线程注册. (此时注册数量为1)
3. 每个任务线程，注册一次. (此时注册数量为`tasks.size() + 1`)
3. 如果Phaser没有终止,其他所有线程执行任务, 然后等待 (此时到达数量为`tasks.size()`.
4. 当前线程取消注册,让注册数等于等待数，其他线程等待结束，进行升级或者终止.

让所有任务互相等待，以完成一组任务，整体完成给定次数后，Phaser终止，程序结束.

#### 等待终止

如果主任务必须在终止后发生,他可以注册然后执行一个相似的循环.

```java
// ...
   phaser.register();
   while (!phaser.isTerminated())
     phaser.arriveAndAwaitAdvance();
```

首先进行注册，然后在Phaser没有终止前，不断的到达，等待升级.知道Phaser终止了，再进行主任务的执行.

#### 等待特定的阶段编号

如果你确定在你的上下文中,Phaser的数量不会超过int的最大值,你可以使用这些相关的构造器来等待特定的某个阶段编号.

```java
 void awaitPhase(Phaser phaser, int phase) {
    // 注册一次
   int p = phaser.register(); // assumes caller not already registered
        // 不断等待
   while (p < phase) {
     if (phaser.isTerminated())
       // ... deal with unexpected termination
     else
         // 阶段升级
       p = phaser.arriveAndAwaitAdvance();
   }
   // 到达指定编号，开始干活
   phaser.arriveAndDeregister();
 }
```

#### 分层的示例

上面讲到Phaser支持分层以获得更好的并发性,这是一个简单的例子.

创建一组任务，使用一个树形的Phasers. 假设一个Task的类，他的构造参数接受一个Phaser. 在调用下方代码的`build`之后，这些任务会开始.

```java
 void build(Task[] tasks, int lo, int hi, Phaser ph) {
    // 如果任务数量大于单个Phaser最大的任务数，说明需要拆分
   if (hi - lo > TASKS_PER_PHASER) {
     for (int i = lo; i < hi; i += TASKS_PER_PHASER) {
       int j = Math.min(i + TASKS_PER_PHASER, hi);
       // 递归调用build, 传入一个新的子Phaser.
       build(tasks, i, j, new Phaser(ph));
     }
   } else {
     // 任务数可以由一个Phaser控制
     for (int i = lo; i < hi; ++i)
         // 创建任务，绑定到当前的Phaser上
       tasks[i] = new Task(ph);
       // assumes new Task(ph) performs ph.register()
   }
 }
```

TASKS_PER_PHASER 的最佳值取决于你期望的同步效率. 越小的值，会让每个阶段的执行块变小，因此速率高. 如果需要更大的执行快，可以设置为高达几百.


### 注意事项

实现控制最大的参与者数量为65535.　如果尝试去注册更多，会导致错误.
但是你可以通过使用树形的Phasers来实现更多的参与者.


## 源码阅读

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
        // 高16位有值,异常,初始化时不可以已有参与者
        if (parties >>> PARTIES_SHIFT != 0)
            throw new IllegalArgumentException("Illegal number of parties");
        // 当前阶段置为0.初始值
        int phase = 0;
        this.parent = parent;
        // 给定的父节点不为空, 是一个树形的Phaser.
        if (parent != null) {
            // 共享同一个root节点,还有所有节点共享队列
            final Phaser root = parent.root;
            this.root = root;
            this.evenQ = root.evenQ;
            this.oddQ = root.oddQ;
            // 如果参与者不为0,当前节点是一个有效的节点，向当前节点的父节点,注册一个参与者,代表(当前节点需要父节点等待)
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
        // 如果有, state=高32位记录阶段号,16-32位记录参与者数量,低16记录没有到达的数量. 初始化的时候，参与者数量和没有到达的数量是一致的
        this.state = (parties == 0) ? (long)EMPTY :
            ((long)phase << PHASE_SHIFT) |
            ((long)parties << PARTIES_SHIFT) |
            ((long)parties);
    }
```

共提供了4个构造方法,本质上都是调用最后一个. 详情看注释.

主要是区分是否是树形,然后对State，父节点，等待队列等进行初始化赋值.

### 变量
    
```java
    // 内部的状态定义, 核心属性
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
    private static final int  ONE_DEREGISTER  = ONE_ARRIVAL|ONE_PARTY; // 一个注销. 操作等于　“参与者减一，同时未到达树也减一”
    private static final int  EMPTY           = 1; // 空, 参与者为0,未到达为1. 方便辨认
    
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

如果内部的信息有一些不对劲, 比如线程为空,或者被中断了, 或者Phaser被别人改了,等等, 都返回true. 否则返回false. 支持中断和超时.

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

用于向Phaser注册参与者.

register系列提供了两个方法,`register`和`bulkRegister`两个方法,本质上都是调用`doRegister`方法.

```java
    private int doRegister(int registrations) {
        // adjustment to state
        // 注册后的State值.
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
                    // 没有未到达的参与者了，　让根节点开始升级
                    if (unarrived == 0)             // wait out advance
                        root.internalAwaitAdvance(phase, null);
                    // 有尚未到达的参与者，更新这次到达后的状态，返回
                    else if (STATE.compareAndSet(this, s, s + adjust))
                        break;
                }
            }
            // 父节点为空, 但是是第一次注册
            else if (parent == null) {              // 1st root registration
                // 计算下一个状态值且CAS设置
                long next = ((long)phase << PHASE_SHIFT) | adjust;
                // 直接设置State，返回
                if (STATE.compareAndSet(this, s, next))
                    break;
            }
            else {
                // 是第一次注册,且是树形结构
                synchronized (this) {               // 1st sub registration
                    // 检查State
                    if (state == s) {               // recheck under lock
                        // 把当前节点注册到其父节点上去.
                        phase = parent.doRegister(1);
                        if (phase < 0)
                            break;
                        // finish registration whenever parent registration
                        // succeeded, even when racing with termination,
                        // since these are part of the same "transaction".
                        // 注册成功, 当前节点的参与者数量等值的设置
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

这是核心的注册方法，主要有三个分支

* 没有父节点，且第一次注册.

这是最简单的，直接将注册后的State更新进去即可.

* 有父节点，但是不是第一次注册

检查下注册后，当前节点是否全部到达了，如果是, 当前节点升级，并且告诉父节点.

* 有父节点，是第一次注册.

首先将当前节点注册到父节点，之后更新当前节点的参与者信息等.


### arrive系列

#### `arrive` 和 `arriveAndDeregister` 到达,不等待其他参与者

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
                // 当前是最后一个到达的
                if (unarrived == 1) {
                    // 参数者数量
                    long n = s & PARTIES_MASK;  // base of next state
                    // 下一个的未到达数量，　当前是最后一个，下一个其实是0
                    int nextUnarrived = (int)n >>> PARTIES_SHIFT;
                    
                    // 不是树形结构
                    if (root == this) {
                        // 如果需要终止, 就终止
                        if (onAdvance(phase, nextUnarrived))
                            n |= TERMINATION_BIT;
                        // 如果没有参与者，也没有到达的，Phaser置为空.
                        else if (nextUnarrived == 0)
                            n |= EMPTY;
                        else
                            //　升级后应该的n
                            n |= nextUnarrived;
                        // 下一个阶段编号
                        int nextPhase = (phase + 1) & MAX_PHASE;
                        // 计算新的State并写入
                        n |= (long)nextPhase << PHASE_SHIFT;
                        STATE.compareAndSet(this, s, n);
                        // 释放等待的节点
                        releaseWaiters(phase);
                    }
                    // 树形结构, 且当前节点全倒了，父节点进行到达行为, 然后当前节点跟进状态
                    else if (nextUnarrived == 0) { // propagate deregistration
                        phase = parent.doArrive(ONE_DEREGISTER);
                        STATE.compareAndSet(this, s, s | EMPTY);
                    }
                    else
                        // 父节点到达
                        phase = parent.doArrive(ONE_ARRIVAL);
                }
                // 如果不是最后一个到达的，　直接返回就好了
                return phase;
            }
        }
    }

```

主要作用是对State中的未到达数量进行递减, 如果递减完，还有未到达的参与者，直接返回当前阶段，如果递减完，当前所有参与者都到达了.
有三个分支:

* 非树形结构

直接计算下一个状态，进行写入.

* 树形结构，且因为注销，没有参与者了.

向父节点注销当前节点，　当前节点置为空.

* 树形结构，且还有参与者

向父节点传递当前节点完全到达的消息.


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
                // 如果当前不是最后一个到达的参与者，阻塞等待
                if (unarrived > 1)
                    return root.internalAwaitAdvance(phase, null);
                // 如果当前节点是最后一个到达的参与者，向父节点进行“到达且等待”操作
                if (root != this)
                    return parent.arriveAndAwaitAdvance();
                // 这里是，当前节点是最后一个到达的参与者，且当前节点不是树形结构
                // 计算新的State并设置State
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
                // 唤醒等待者
                releaseWaiters(phase);
                return nextPhase;
            }
        }
    }
```

到达一个参与者，且阻塞等待Phaser的升级行为. 首先将当前Phaser的状态进行递减，之后主要有三个分支:

* 不是最后一个到达的.

从跟进点进行等待升级

* 是最后一个到达的，且有父节点

调用父节点的`arriveAndAwaitAdvance`,向父节点报告当前节点已经完全到达，开始等待升级.

* 是最后一个到达的，且是根节点

计算新的状态，设置状态然后唤醒等待者.


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
    // 只有根节点调用,可能会阻塞
    private int internalAwaitAdvance(int phase, QNode node) {
        // assert root == this;
        // 奇偶队列交替使用，确保旧的是空的
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
                // 入队
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

让当前线程自旋或者进入队列等待Phaser的升级，也就是等待其他所有参与者的到达.

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


## 总结

Phaser是一个用于多阶段任务的同步器，没有使用AQS框架来实现，而是自己实现的。

内部的核心还是State的定义.

高32位记录当前的阶段编号,16-32为记录共有多少个参与者, 低16位记录还有多少个参与者没有到达.

提供三类方法:

* 注册

修改16-32位，与其他同步器相比，提供了更多的灵活性，可以修改参与者的数量

* 到达

修改低16位，当全部到达后，进行升级，升级通过修改高32位来记录阶段编号

* 等待

让先到达的线程，阻塞等待所有参与者的到达，也就是升级行为完成后，被唤醒.

为了支持更大的并发度，Phaser支持以树结构创建，叶子节点接受所有参与者的到达，控制所有注册到自己的参与者. 父节点控制自己的子节点.
根节点控制所有是否进行放行，唤醒所有等待线程.


<br/>

完.



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