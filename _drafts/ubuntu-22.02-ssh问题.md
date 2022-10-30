升级到22.02之后，给gitlab添加ssh-key. 还是不能拉去代码.

原因:

2020-09-27 8.4 版本，废弃了rsa的算法，

https://www.openssh.com/txt/release-8.4

https://fedoraproject.org/wiki/Changes/StrongCryptoSettings2


解决办法:

1. 使用ed25519的key，gitlab也支持
2. 在~/.ssh/config中对应域名下添加: PubkeyAcceptedKeyTypes +ssh-rsa.


坑我两天