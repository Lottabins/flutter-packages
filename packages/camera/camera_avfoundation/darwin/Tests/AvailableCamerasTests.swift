// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import XCTest

@testable import camera_avfoundation

final class AvailableCamerasTest: XCTestCase {
  private func createCameraPlugin(with deviceDiscoverer: MockCameraDeviceDiscoverer) -> CameraPlugin
  {
    return CameraPlugin(
      registry: MockFlutterTextureRegistry(),
      messenger: MockFlutterBinaryMessenger(),
      globalAPI: MockGlobalEventApi(),
      deviceDiscoverer: deviceDiscoverer,
      permissionManager: MockCameraPermissionManager(),
      deviceFactory: { _ in MockCaptureDevice() },
      captureSessionFactory: { MockCaptureSession() },
      captureDeviceInputFactory: MockCaptureDeviceInputFactory(),
      captureSessionQueue: DispatchQueue(label: "io.flutter.camera.captureSessionQueue")
    )
  }

  func testAvailableCamerasShouldReturnAllCamerasOnMultiCameraIPhone() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      // iPhone 13 Cameras:
      let wideAngleCamera = MockCaptureDevice()
      wideAngleCamera.uniqueID = "0"
      wideAngleCamera.position = .back

      let frontFacingCamera = MockCaptureDevice()
      frontFacingCamera.uniqueID = "1"
      frontFacingCamera.position = .front

      let ultraWideCamera = MockCaptureDevice()
      ultraWideCamera.uniqueID = "2"
      ultraWideCamera.position = .back

      let telephotoCamera = MockCaptureDevice()
      telephotoCamera.uniqueID = "3"
      telephotoCamera.position = .back

      var requiredTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
        .builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera,
      ]
      var cameras = [wideAngleCamera, frontFacingCamera, telephotoCamera, ultraWideCamera]

      XCTAssertEqual(deviceTypes, requiredTypes)
      XCTAssertEqual(mediaType, .video)
      XCTAssertEqual(position, .unspecified)
      return cameras
    }

    var resultValue: [PlatformCameraDescription]?
    cameraPlugin.getAvailableCameras { result in
      resultValue = self.assertSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    // Verify the result.
    XCTAssertEqual(resultValue?.count, 4)
  }

  func testAvailableCamerasShouldReturnTwoCamerasOnDualCameraIPhone() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      // iPhone 8 Cameras:
      let wideAngleCamera = MockCaptureDevice()
      wideAngleCamera.uniqueID = "0"
      wideAngleCamera.position = .back

      let frontFacingCamera = MockCaptureDevice()
      frontFacingCamera.uniqueID = "1"
      frontFacingCamera.position = .front

      var requiredTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
        .builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera,
      ]
      let cameras = [wideAngleCamera, frontFacingCamera]

      XCTAssertEqual(deviceTypes, requiredTypes)
      XCTAssertEqual(mediaType, .video)
      XCTAssertEqual(position, .unspecified)
      return cameras
    }

    var resultValue: [PlatformCameraDescription]?
    cameraPlugin.getAvailableCameras { result in
      resultValue = self.assertSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    // Verify the result.
    XCTAssertEqual(resultValue?.count, 2)
  }

  func testAvailableCamerasShouldReturnExternalLensDirectionForUnspecifiedCameraPosition() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      let unspecifiedCamera = MockCaptureDevice()
      unspecifiedCamera.uniqueID = "0"
      unspecifiedCamera.position = .unspecified

      var requiredTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
        .builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera,
      ]
      let cameras = [unspecifiedCamera]

      XCTAssertEqual(deviceTypes, requiredTypes)
      XCTAssertEqual(mediaType, .video)
      XCTAssertEqual(position, .unspecified)
      return cameras
    }

    var resultValue: [PlatformCameraDescription]?
    cameraPlugin.getAvailableCameras { result in
      resultValue = self.assertSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    XCTAssertEqual(resultValue?.first?.lensDirection, .external)
  }

  func testAvailableCamerasShouldReportVirtualDevices() {
    let mockDeviceDiscoverer = MockCameraDeviceDiscoverer()
    let cameraPlugin = createCameraPlugin(with: mockDeviceDiscoverer)
    let expectation = self.expectation(description: "Result finished")

    mockDeviceDiscoverer.discoverySessionStub = { deviceTypes, mediaType, position in
      // A Pro device exposes a virtual triple camera alongside the physical
      // wide-angle camera.
      let tripleCamera = MockCaptureDevice()
      tripleCamera.uniqueID = "0"
      tripleCamera.position = .back
      tripleCamera.deviceType = .builtInTripleCamera
      tripleCamera.isVirtualDevice = true

      let wideAngleCamera = MockCaptureDevice()
      wideAngleCamera.uniqueID = "1"
      wideAngleCamera.position = .back
      wideAngleCamera.deviceType = .builtInWideAngleCamera
      wideAngleCamera.isVirtualDevice = false

      return [tripleCamera, wideAngleCamera]
    }

    var resultValue: [PlatformCameraDescription]?
    cameraPlugin.getAvailableCameras { result in
      resultValue = self.assertSuccess(result)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 30, handler: nil)

    XCTAssertEqual(resultValue?.count, 2)
    // The virtual triple camera reports its primary (wide) lens and is flagged
    // as virtual; the physical wide camera is not.
    XCTAssertEqual(resultValue?[0].lensType, .wide)
    XCTAssertTrue(resultValue?[0].isVirtualDevice ?? false)
    XCTAssertEqual(resultValue?[1].lensType, .wide)
    XCTAssertFalse(resultValue?[1].isVirtualDevice ?? true)
  }
}
