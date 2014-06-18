安装过程中有些命令要有sudo才能安装，如果遇到Permission denied

1、安装Ruby

  安装ruby
  
  1）安装rvm,curl -sSL https://get.rvm.io | bash -s stable
  
  2）启用rvm,source /home/ubuntu/.rvm/scripts/rvm
  
  3）ruby安装，安装1.9.3，rvm install ruby 1.9.3

2、安装zlib

  要在python安装之前安装，
  
  必须通过代码安装才能起效。
  
  下载zlib-1.2.7.tar.gz，下载地址：
  
  http://download.chinaunix.net/download.php?id=40893&ResourceID=12241
  
  解压
  
  configure、make、make install
  
  然后重新安装python（2.6版本）和setuptools（4.0版本）

3、安装Pyhon2.6版本

  由于ubuntu 14.04上，默认的Python为2.7，我们开发依赖的rubypython，在2.7版本下有问题。需要安装使用python2.6版。
  
  1）安装Python2.6
  
  1.1 下载Python-2.6.6.tgz，下载地址：http://www.python.org/ftp/python/2.6.6/Python-2.6.6.tgz
  
  sudo wget http://www.python.org/ftp/python/2.6.6/Python-2.6.6.tgz
  
  青云上下载这个包很慢，可以本地下载好传上去
  
  1.2 解压tgz ：
  
  tar -xzvf Python-2.6.6.tgz  
  
  1.3 cd 到解压后的文件夹中，进行Python的make 安装

  ./configure --enable-shared  （安装在了/usr/local/）
  
  make  
  
  make altinstall

1.4 建立lib连接：sudo ln -s /usr/local/lib/libpython2.6.so.1.0  /usr/lib/libpython2.6.so.1.0

1.5 最后还要修改下python软连接。使Python的系统版本切换到Python2.6版本

which python

/usr/bin/python

sudo rm /usr/bin/python

sudo ln -s /usr/local/bin/python2.6 /usr/bin/python

sudo rm /usr/bin/python2

sudo ln -s /usr/local/bin/python2.6 /usr/bin/python2

测试是否安装成功

ubuntu@i-pareq9il:/usr/bin$ python

Python 2.6.6 (r266:84292, Jun 18 2014, 16:47:11) 

[GCC 4.8.2] on linux3

Type "help", "copyright", "credits" or "license" for more information.

>>> 


4、安装setuptools

必须通过源码安装，版本setuptools-4.1b1.zip，下载地址：

https://bitbucket.org/pypa/setuptools/downloads/setuptools-4.1b1.zip

解压安装

tar -xzvf setuptools-4.1b1.zip

cd 到解压文件夹

使用 sudo python2.6 setup.py install 安装

如果出现如下错误，

ImportError: No module named _sha256

这是因为在2.6中缺少了hash相关的模块，可以从2.7中拷贝

cp /usr/local/lib/python2.7/lib-dynload/_hashlib.so /usr/local/lib/python2.6/lib-dynload/_hashlib.so

关键是找_hashlib.so，

5、安装ffi

Ruby FFI库可以访问从共享库中加载的本地代码，类似于c的动态链接库概念

gem install ffi

建议在使用gem前换下source源,默认源下载慢

gem source -a http://ruby.taobao.org

6、安装rubypython

gem install rubypython

7、安装qingcloud sdk

需要代码安装，

git clone https://github.com/yunify/qingcloud-sdk-python.git

cd qingcloud-sdk-python

sudo python2.6 setup.py install 

8、测试

1)vi rubypython.rb

2)加入如下代码

require "rubypython"

RubyPython.start # start the Python interpreter

cPickle = RubyPython.import("qingcloud.iaas")

RubyPython.stop # stop the Python interpreter

3)ruby rubypython.rb



