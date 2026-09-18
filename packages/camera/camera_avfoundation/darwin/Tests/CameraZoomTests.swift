// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import XCTest

@testable import camera_avfoundation

final class CameraZoomTests: XCTestCase {
  private func createCamera() -> (Camera, MockCaptureDevice) {
    let mockDevice = MockCaptureDevice()

    let configuration = CameraTestUtils.createTestCameraConfiguration()
    configuration.videoCaptureDeviceFactory = { _ in mockDevice }
    let camera = CameraTestUtils.createTestCamera(configuration)

    return (camera, mockDevice)
  }

  func testInitialZoomUsesWideConstituentForUltraWideVirtualCameras() throws {
    for deviceType: AVCaptureDevice.DeviceType in [.builtInTripleCamera, .builtInDualWideCamera] {
      let device = MockCaptureDevice()
      device.deviceType = deviceType
      device.virtualDeviceSwitchOverVideoZoomFactors = [2, 6]
      var initialZoom: CGFloat?
      device.setVideoZoomFactorStub = { initialZoom = $0 }
      let configuration = CameraTestUtils.createTestCameraConfiguration()
      configuration.videoCaptureDeviceFactory = { _ in device }

      _ = try DefaultCamera(configuration: configuration)

      XCTAssertEqual(initialZoom, 2)
    }
  }

  func testInitialZoomLeavesOtherCameraTypesUnchanged() throws {
    for deviceType: AVCaptureDevice.DeviceType in [
      .builtInDualCamera, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera,
    ] {
      let device = MockCaptureDevice()
      device.deviceType = deviceType
      device.virtualDeviceSwitchOverVideoZoomFactors = [3]
      device.setVideoZoomFactorStub = { _ in XCTFail("Should preserve the device's initial zoom") }
      let configuration = CameraTestUtils.createTestCameraConfiguration()
      configuration.videoCaptureDeviceFactory = { _ in device }

      _ = try DefaultCamera(configuration: configuration)
    }
  }

  func testInitialZoomHandlesMissingSwitchOverFactors() throws {
    let device = MockCaptureDevice()
    device.deviceType = .builtInTripleCamera
    device.setVideoZoomFactorStub = { _ in XCTFail("No wide zoom factor is available") }
    let configuration = CameraTestUtils.createTestCameraConfiguration()
    configuration.videoCaptureDeviceFactory = { _ in device }

    _ = try DefaultCamera(configuration: configuration)
  }

  func testInitialZoomPropagatesConfigurationLockFailure() {
    let device = MockCaptureDevice()
    device.deviceType = .builtInDualWideCamera
    device.virtualDeviceSwitchOverVideoZoomFactors = [2]
    let lockError = NSError(domain: "CameraZoomTests", code: 1)
    device.lockForConfigurationStub = { throw lockError }
    device.setVideoZoomFactorStub = { _ in XCTFail("Must not set zoom without a configuration lock")
    }
    let configuration = CameraTestUtils.createTestCameraConfiguration()
    configuration.videoCaptureDeviceFactory = { _ in device }

    XCTAssertThrowsError(try DefaultCamera(configuration: configuration)) { error in
      XCTAssertEqual(error as NSError, lockError)
    }
  }

  func testSetZoomLevel_setVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    mockDevice.maxAvailableVideoZoomFactor = 2.0
    mockDevice.minAvailableVideoZoomFactor = 0.0

    let targetZoom = CGFloat(1.0)

    var setVideoZoomFactorCalled = false
    mockDevice.setVideoZoomFactorStub = { zoom in
      XCTAssertEqual(zoom, targetZoom)
      setVideoZoomFactorCalled = true
    }

    let expectation = expectation(description: "Call completed")

    camera.setZoomLevel(targetZoom) {
      result in
      let _ = self.assertSuccess(result)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)

    XCTAssertTrue(setVideoZoomFactorCalled)
  }

  func testSetZoomLevel_returnsError_forZoomLevelBlowMinimum() {
    let (camera, mockDevice) = createCamera()

    // Allowed zoom range between 2.0 and 3.0
    mockDevice.maxAvailableVideoZoomFactor = 2.0
    mockDevice.minAvailableVideoZoomFactor = 3.0

    let expectation = expectation(description: "Call completed")

    camera.setZoomLevel(CGFloat(1.0)) { result in
      switch result {
      case .failure(let error as PigeonError):
        XCTAssertEqual(error.code, "ZOOM_ERROR")
      default:
        XCTFail("Expected failure")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)
  }

  func testSetZoomLevel_returnsError_forZoomLevelAboveMaximum() {
    let (camera, mockDevice) = createCamera()

    // Allowed zoom range between 0.0 and 1.0
    mockDevice.maxAvailableVideoZoomFactor = 0.0
    mockDevice.minAvailableVideoZoomFactor = 1.0

    let expectation = expectation(description: "Call completed")

    camera.setZoomLevel(CGFloat(2.0)) { result in
      switch result {
      case .failure(let error as PigeonError):
        XCTAssertEqual(error.code, "ZOOM_ERROR")
      default:
        XCTFail("Expected failure")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)
  }

  func testMaximumAvailableZoomFactor_returnsDeviceMaxAvailableVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    let targetZoom = CGFloat(1.0)

    mockDevice.maxAvailableVideoZoomFactor = CGFloat(targetZoom)

    XCTAssertEqual(camera.maximumAvailableZoomFactor, targetZoom)
  }

  func testMinimumAvailableZoomFactor_returnsDeviceMinAvailableVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    let targetZoom = CGFloat(1.0)

    mockDevice.minAvailableVideoZoomFactor = CGFloat(targetZoom)

    XCTAssertEqual(camera.minimumAvailableZoomFactor, targetZoom)
  }
}
