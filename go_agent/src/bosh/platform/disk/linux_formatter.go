package disk

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"fmt"
	"strings"
)

type linuxFormatter struct {
	runner boshsys.CmdRunner
	fs     boshsys.FileSystem
}

func NewLinuxFormatter(runner boshsys.CmdRunner, fs boshsys.FileSystem) (formatter linuxFormatter) {
	formatter.runner = runner
	formatter.fs = fs
	return
}

func (f linuxFormatter) Format(partitionPath string, fsType FileSystemType) (err error) {
	if f.partitionHasGivenType(partitionPath, fsType) {
		return
	}

	switch fsType {
	case FileSystemSwap:
		_, _, _, err = f.runner.RunCommand("mkswap", partitionPath)
		if err != nil {
			err = bosherr.WrapError(err, "Shelling out to mkswap")
		}

	case FileSystemExt4:
		if f.fs.FileExists("/sys/fs/ext4/features/lazy_itable_init") {
			_, _, _, err = f.runner.RunCommand("mke2fs", "-t", "ext4", "-j", "-E", "lazy_itable_init=1", partitionPath)
		} else {
			_, _, _, err = f.runner.RunCommand("mke2fs", "-t", "ext4", "-j", partitionPath)
		}
		if err != nil {
			err = bosherr.WrapError(err, "Shelling out to mke2fs")
		}
	}
	return
}

func (f linuxFormatter) WriteFstabs(partitionPath string, mountPoint string) (err error) {
	uuid, err := f.partitionGetUUID(partitionPath)
	if err != nil {
		err = bosherr.WrapError(err, "Get partition UUID fail")
	}

	content :=  "sed -i '$a " + uuid + " " + mountPoint + " ext4 defaults 0 2' /etc/fstab "

	_, _, _, err = f.runner.RunCommand("bash","-c", content)
	if err != nil {
		err = bosherr.WrapError(err, "exec command sed -i fail")
	}
	return
}

func (f linuxFormatter) partitionHasGivenType(partitionPath string, fsType FileSystemType) bool {
	stdout, _, _, err := f.runner.RunCommand("blkid", "-p", partitionPath)
	if err != nil {
		return false
	}

	return strings.Contains(stdout, fmt.Sprintf(` TYPE="%s"`, fsType))
}

func (f linuxFormatter) partitionGetUUID(partitionPath string) (string, error) {
	stdout, _, _, err := f.runner.RunCommand("blkid", "-p", partitionPath)
	if err != nil {
		return "", bosherr.WrapError(err, "blkid exec error ")
	}

	fmt.Println("zff partitionGetUUID stdout: %s", stdout)
	results:= strings.Replace(stdout, "\"", "", -1)
	fmt.Println("zff partitionGetUUID results: %s", results)
	result := strings.Fields(results)

	return result[1], nil
}
