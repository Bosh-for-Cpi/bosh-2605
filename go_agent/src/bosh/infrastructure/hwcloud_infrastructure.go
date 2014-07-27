package infrastructure

import (
	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

const hwcloudInfrastructureLogTag = "hwcloudInfrastructure"

type hwcloudInfrastructure struct {
	metadataService    MetadataService
	registry           Registry
	platform           boshplatform.Platform
	devicePathResolver boshdpresolv.DevicePathResolver
	logger             boshlog.Logger
}

func NewHwcloudInfrastructure(
	metadataService MetadataService,
	registry Registry,
	platform boshplatform.Platform,
	devicePathResolver boshdpresolv.DevicePathResolver,
	logger boshlog.Logger,
) (inf hwcloudInfrastructure) {
	inf.metadataService = metadataService
	inf.registry = registry
	inf.platform = platform
	inf.devicePathResolver = devicePathResolver
	inf.logger = logger
	return
}

func (inf hwcloudInfrastructure) GetDevicePathResolver() boshdpresolv.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf hwcloudInfrastructure) SetupSsh(username string) error {
	publicKey, err := inf.metadataService.GetPublicKey()
	if err != nil {
		return bosherr.WrapError(err, "Error getting public key")
	}

	// var publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCw+En/U91Jxkx2C5HLeHAvjrAUtfXkSepqSYazJsAxovAYQx1UiL1utDrUVRClu8LKUCmckavOUdC472sHSBS6WARl0bsx3wzmUMi1LbZybXzcvqQpWDdpvs/j+UweVqOFqXxZDtYE/xWDKzUMsM88hP0+j4T2K0P8J4qkmONPe4/o4cBPhd72UVM9cPKzKkLmRuXpBBq7WBBC/lnDOZZ2F1psC6dj21yK4Jftr2jTYfxpOzdHIiq5tNrSrizDUMzBfdmN4DmS219W2B7vxX61PeWw0QJP9YwL2zLxyIQfcxeH/lWr+NG5Z6ZZOlpD7eVhjXDg79ZyNCW2GgmTMcrL Generated by HwCloud"

	return inf.platform.SetupSsh(publicKey, username)
}

func (inf hwcloudInfrastructure) GetSettings() (boshsettings.Settings, error) {
	settings, err := inf.registry.GetSettings()
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting settings from registry")
	}

	return settings, nil
}

func (inf hwcloudInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return inf.platform.SetupDhcp(networks)
}

func (inf hwcloudInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	if devicePath == "" {
		inf.logger.Info(hwcloudInfrastructureLogTag, "Ephemeral disk path is empty")
		return "", true
	}

	return inf.platform.NormalizeDiskPath(devicePath)
}
