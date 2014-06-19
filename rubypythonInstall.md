
由于rubypython需要用到Python的动态链接库，但是默认情况下，rubypython无法找到

需要手动处理

1、找到Python2.7的动态链接库

find / -name libpython2.7.so.1.0

/usr/lib/x86_64-linux-gnu/libpython2.7.so.1.0

2、创建软连接

ln -s /usr/lib/x86_64-linux-gnu/libpython2.7.so.1.0  /usr/lib/libpython2.7.so.1.0

安装ruby环境

1、curl -sSL https://get.rvm.io | bash -s stable

2、source /etc/profile.d/rvm.sh

3、echo "source /etc/profile.d/rvm.sh" >> ~/.bashrc

4、rvm install 1.9.3

安装ffi 、rubypython

1、gem source -r https://rubygems.org/

2、gem source -a http://ruby.taobao.org

3、gem install ffi

4、gem install rubypython

安装qingcloud sdk

1、apt-get install git

2、git clone https://github.com/yunify/qingcloud-sdk-python.git

3、cd qingcloud-sdk-python

4、python setup.py install


测试

1、测试rubypython功能

vi rubypython.rb

require "rubypython"

RubyPython.start # start the Python interpreter

cPickle = RubyPython.import("cPickle")

p cPickle.dumps("Testing RubyPython.").rubify

RubyPython.stop # stop the Python interpreter

2、测试sdk功能

import qingcloud.iaas

conn = qingcloud.iaas.connect_to_zone(

        'gd1',
        
        'DNQWQIIMXMXZNYPLEXNN',
        
        'i6Nn2Zq1NJ66geckRIzmMx0qVwPVUJYCQpbWDNw2'
        
    )

ret = conn.describe_instances(

        image_id='trustysrvx64a',
        
        status=['running', 'stopped']
        
      )

print ret
