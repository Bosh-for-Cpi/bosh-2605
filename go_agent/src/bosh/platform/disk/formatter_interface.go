package disk

type FileSystemType string

const (
	FileSystemSwap FileSystemType = "swap"
	FileSystemExt4 FileSystemType = "ext4"
)

type Formatter interface {
	Format(partitionPath string, fsType FileSystemType) (err error)
	WriteFstabs(partitionPath string, mountPoint string) (err error)
	ChangeDevicePath(devicePath, mountPoint string) (err error)
	GetFstabDevicePath() (result string, err error)
}
