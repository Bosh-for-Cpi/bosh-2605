
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

4、安装rubypython，修改了部分代码

从git上下载修改后的源码安装

git clone https://github.com/Bosh-for-Cpi/rubypython.git

进入rubypython文件夹后，

gem build rubypython.gemspec

gem install rubypython-0.6.3.gem

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

正常输出：

"S'Testing RubyPython.'\n."

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

正常输出：

{u'action': u'DescribeInstancesResponse', u'instance_set': [{u'vcpus_current': 1, u'instance_id': u'i-zqzojyoh', u'vxnets': [{u'vxnet_name': u'primary vxnet', u'vxnet_type': 1, u'vxnet_id': u'vxnet-0', u'nic_id': u'52:54:c8:9f:63:d1', u'private_ip': u''}], u'memory_current': 1024, u'lastest_snapshot_time': u'', u'sub_code': 0, u'transition_status': u'', u'instance_name': u'Leon', u'instance_type': u'c1m1', u'create_time': u'2014-06-18T02:27:09Z', u'status': u'stopped', u'owner': u'usr-HJOoBo2T', u'status_time': u'2014-06-18T11:09:05Z', u'image': {u'processor_type': u'64bit', u'platform': u'linux', u'image_size': 20, u'image_name': u'Ubuntu Server 14.04 LTS 64bit', u'image_id': u'trustysrvx64a', u'os_family': u'ubuntu', u'provider': u'system'}, u'description': None}, {u'vcpus_current': 1, u'instance_id': u'i-fokn7r0i', u'vxnets': [{u'vxnet_name': u'primary vxnet', u'vxnet_type': 1, u'vxnet_id': u'vxnet-0', u'nic_id': u'52:54:fe:68:ae:42', u'private_ip': u''}], u'memory_current': 1024, u'lastest_snapshot_time': u'', u'sub_code': 0, u'transition_status': u'', u'instance_name': u'test11', u'instance_type': u'c1m1', u'create_time': u'2014-06-18T13:33:49Z', u'status': u'stopped', u'owner': u'usr-HJOoBo2T', u'status_time': u'2014-06-18T13:34:28Z', u'image': {u'processor_type': u'64bit', u'platform': u'linux', u'image_size': 20, u'image_name': u'Ubuntu Server 14.04 LTS 64bit', u'image_id': u'trustysrvx64a', u'os_family': u'ubuntu', u'provider': u'system'}, u'description': None}, {u'vcpus_current': 1, u'eip': {u'eip_id': u'eip-lxempw9c', u'bandwidth': 4, u'eip_addr': u'121.201.8.66'}, u'vxnets': [{u'vxnet_name': u'primary vxnet', u'vxnet_type': 1, u'vxnet_id': u'vxnet-0', u'nic_id': u'52:54:59:33:b2:ca', u'private_ip': u'10.60.32.132'}], u'memory_current': 1024, u'lastest_snapshot_time': u'', u'sub_code': 0, u'transition_status': u'', u'instance_id': u'i-coyij9m6', u'instance_type': u'c1m1', u'create_time': u'2014-06-18T12:01:56Z', u'status': u'running', u'owner': u'usr-HJOoBo2T', u'status_time': u'2014-06-19T01:34:53Z', u'instance_name': u'wjq', u'image': {u'processor_type': u'64bit', u'platform': u'linux', u'image_size': 20, u'image_name': u'Ubuntu Server 14.04 LTS 64bit', u'image_id': u'trustysrvx64a', u'os_family': u'ubuntu', u'provider': u'system'}, u'description': None}, {u'vcpus_current': 1, u'eip': {u'eip_id': u'eip-kha55lf3', u'bandwidth': 4, u'eip_addr': u'121.201.7.212'}, u'vxnets': [{u'vxnet_name': u'primary vxnet', u'vxnet_type': 1, u'vxnet_id': u'vxnet-0', u'nic_id': u'52:54:d4:fb:66:e9', u'private_ip': u'10.60.49.64'}], u'memory_current': 1024, u'lastest_snapshot_time': u'', u'sub_code': 0, u'transition_status': u'', u'instance_id': u'i-gmarffqy', u'instance_type': u'c1m1', u'create_time': u'2014-06-19T02:57:09Z', u'status': u'running', u'owner': u'usr-HJOoBo2T', u'status_time': u'2014-06-19T02:57:09Z', u'instance_name': u'Leon_test', u'image': {u'processor_type': u'64bit', u'platform': u'linux', u'image_size': 20, u'image_name': u'Ubuntu Server 14.04 LTS 64bit', u'image_id': u'trustysrvx64a', u'os_family': u'ubuntu', u'provider': u'system'}, u'description': None}], u'ret_code': 0, u'total_count': 4}
