1、压缩/var/vcap目录，注意需要保留原有的文件夹属性
tar pzcvf  /var/vcap vcap.microbosh.tgz

2、降压缩包拷贝到新的机子上去

3、在新的机子创建vcap账户

#每台单板增加用户组、用户
vcap_user_groups='admin,adm,audio,cdrom,dialout,floppy,video,dip,plugdev';
groupadd --system admin;
groupadd -g 1000 vcap;
useradd -m --comment 'BOSH System User' -u 1000 -g vcap vcap;
echo 'vcap:c1oudc0w' | chpasswd;
echo 'root:c1oudc0w' | chpasswd;
usermod -G admin,adm,audio,cdrom,dialout,floppy,video,dip,plugdev vcap;
usermod -s /bin/bash vcap;

4、解压的时候tar pzxvf vcap.microbosh.tgz
