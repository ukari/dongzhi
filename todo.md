
# 介绍LD_PRELOAD
- 通过做实验学习ld、nix-ld区别，目录/lib/ld-linux-???.so.2 /lib64/ld-linux-x86-64.so.2
    - dockerfile from scrath环境测试ld对编译出的依赖so的可执行文件的影响

```
bash-5.2# readelf -l /.stack/programs/x86_64-linux/ghc-9.6.6/lib/ghc-9.6.6/bin/ghc-pkg | grep interpreter
[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
```
找到可执行文件解释器的方法，解释器就是ld吗？

crane 解压？ `crane export - fs.tar < test.tar.gz`
https://labs.iximiuz.com/tutorials/extracting-container-image-filesystem
skopeo

# ghc编译的可执行文件的大小的影响因素
https://stackoverflow.com/questions/6115459/small-haskell-program-compiled-with-ghc-into-huge-binary