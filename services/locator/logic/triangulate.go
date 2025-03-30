package logic

import "locator/models"

func Triangulate(bundle models.SignalBundle) models.Detection {
	// TODO: Real triangulation
	return models.Detection{
		X:         500,
		Y:         500,
		Timestamp: bundle.SignalTimestamp,
	}
}
