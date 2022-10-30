# 步骤


1. 远程服务监听Debug端口，启动脚本添加: ```INTELLIJ_DEBUG_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:4103"```

2. 本地IDEA,添加 JVM Debug Remote. 连接对应的端口.

3. 本地修改代码, 添加日志打印等. 

4. 点击 Run->Debugging Action -> reload Changed Classes


5. 调用接口等测试，线上已经成功热部署. 节省重新打包的时间~


