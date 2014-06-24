package infrastructure

import (
	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

const qingcloudInfrastructureLogTag = "qingcloudInfrastructure"

type qingcloudInfrastructure struct {
	metadataService    MetadataService
	registry           Registry
	platform           boshplatform.Platform
	devicePathResolver boshdpresolv.DevicePathResolver
	logger             boshlog.Logger
}

func NewqingcloudInfrastructure(
	metadataService MetadataService,
	registry Registry,
	platform boshplatform.Platform,
	devicePathResolver boshdpresolv.DevicePathResolver,
	logger boshlog.Logger,
) (inf qingcloudInfrastructure) {
	inf.metadataService = metadataService
	inf.registry = registry
	inf.platform = platform
	inf.devicePathResolver = devicePathResolver
	inf.logger = logger
	return
}

func (inf qingcloudInfrastructure) GetDevicePathResolver() boshdpresolv.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf qingcloudInfrastructure) SetupSsh(username string) error {
	publicKey, err := inf.metadataService.GetPublicKey()
	if err != nil {
		return bosherr.WrapError(err, "Error getting public key")
	}

	return inf.platform.SetupSsh(publicKey, username)
}

func (inf qingcloudInfrastructure) GetSettings() (boshsettings.Settings, error) {
	settings, err := inf.registry.GetSettings()
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting settings from registry")
	}

	return settings, nil
}

func (inf qingcloudInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return inf.platform.SetupDhcp(networks)
}

func (inf qingcloudInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	if devicePath == "" {
		inf.logger.Info(qingcloudInfrastructureLogTag, "Ephemeral disk path is empty")
		return "", true
	}

	return inf.platform.NormalizeDiskPath(devicePath)
}
