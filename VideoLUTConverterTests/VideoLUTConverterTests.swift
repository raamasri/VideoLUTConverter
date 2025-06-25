//
//  VideoLUTConverterTests.swift
//  VideoLUTConverterTests
//
//  Created by raama srivatsan on 10/25/24.
//

import XCTest
import Foundation
@testable import VideoLUTConverter

class VideoLUTConverterTests: XCTestCase {

    func testProjectStateInitialization() {
        let projectState = ProjectState()
        
        XCTAssertTrue(projectState.videoURLs.isEmpty)
        XCTAssertNil(projectState.primaryLUTURL)
        XCTAssertNil(projectState.secondaryLUTURL)
        XCTAssertEqual(projectState.secondLUTOpacity, 1.0)
        XCTAssertTrue(projectState.useGPU)
        XCTAssertFalse(projectState.isReadyForPreview)
        XCTAssertFalse(projectState.isReadyForExport)
    }
    
    func testVideoURLManagement() {
        let projectState = ProjectState()
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        
        // Test adding video URL
        projectState.addVideoURL(testURL)
        XCTAssertEqual(projectState.videoURLs.count, 1)
        XCTAssertEqual(projectState.videoURLs.first, testURL)
        
        // Test preventing duplicate URLs
        projectState.addVideoURL(testURL)
        XCTAssertEqual(projectState.videoURLs.count, 1)
        
        // Test removing video URL
        projectState.removeVideoURL(testURL)
        XCTAssertTrue(projectState.videoURLs.isEmpty)
    }
    
    func testLUTConfiguration() {
        let projectState = ProjectState()
        let primaryLUT = URL(fileURLWithPath: "/test/primary.cube")
        let secondaryLUT = URL(fileURLWithPath: "/test/secondary.cube")
        
        // Test primary LUT
        projectState.setPrimaryLUT(primaryLUT)
        XCTAssertEqual(projectState.primaryLUTURL, primaryLUT)
        
        // Test secondary LUT
        projectState.setSecondaryLUT(secondaryLUT)
        XCTAssertEqual(projectState.secondaryLUTURL, secondaryLUT)
        XCTAssertTrue(projectState.hasSecondaryLUT)
        
        // Test opacity
        projectState.secondLUTOpacity = 0.5
        XCTAssertEqual(projectState.opacityPercentage, 50)
    }
    
    func testValidationLogic() {
        let projectState = ProjectState()
        
        // Test initial state
        let initialValidation = projectState.validateConfiguration()
        XCTAssertFalse(initialValidation.isValid)
        XCTAssertEqual(initialValidation.errorMessage, "No video files selected")
        
        // Add video but no LUT
        projectState.addVideoURL(URL(fileURLWithPath: "/test/video.mp4"))
        let videoOnlyValidation = projectState.validateConfiguration()
        XCTAssertFalse(videoOnlyValidation.isValid)
        XCTAssertEqual(videoOnlyValidation.errorMessage, "No primary LUT selected")
        
        // Add primary LUT but no export directory
        projectState.setPrimaryLUT(URL(fileURLWithPath: "/test/lut.cube"))
        let noExportValidation = projectState.validateConfiguration()
        XCTAssertFalse(noExportValidation.isValid)
        XCTAssertEqual(noExportValidation.errorMessage, "No export directory selected")
        
        // Add export directory - should be valid
        projectState.setExportDirectory(URL(fileURLWithPath: "/test/output"))
        let validValidation = projectState.validateConfiguration()
        XCTAssertTrue(validValidation.isValid)
        XCTAssertNil(validValidation.errorMessage)
    }
    
    func testOutputFileNaming() {
        let projectState = ProjectState()
        let videoURL = URL(fileURLWithPath: "/test/input_video.mp4")
        let secondaryLUT = URL(fileURLWithPath: "/test/creative_lut.cube")
        
        projectState.setSecondaryLUT(secondaryLUT)
        projectState.secondLUTOpacity = 0.75
        
        let fileName = projectState.generateOutputFileName(for: videoURL)
        let expectedName = "input_video_converted_creative_lut_75percent.mp4"
        XCTAssertEqual(fileName, expectedName)
    }
    
    func testStringUtilities() {
        // Test ANSI color stripping
        let textWithColors = "\u{001B}[31mRed Text\u{001B}[0m Normal Text"
        let cleanText = StringUtilities.stripANSIColors(from: textWithColors)
        XCTAssertEqual(cleanText, "Red Text Normal Text")
        
        // Test opacity formatting
        let opacity1 = StringUtilities.formatOpacity(0.5)
        XCTAssertEqual(opacity1, "0.5")
        
        let opacity2 = StringUtilities.formatOpacity(1.0)
        XCTAssertEqual(opacity2, "1")
        
        // Test log message creation
        let logMessage = StringUtilities.createLogMessage("Test message")
        XCTAssertTrue(logMessage.contains("Test message"))
        XCTAssertTrue(logMessage.contains("["))
        XCTAssertTrue(logMessage.hasSuffix("\n"))
    }
    
    func testFilterBuilderEncodingArguments() {
        // Test GPU encoding arguments
        let gpuArgs = FilterBuilder.buildEncodingArguments(useGPU: true)
        XCTAssertTrue(gpuArgs.contains("-c:v"))
        XCTAssertTrue(gpuArgs.contains("h264_videotoolbox"))
        XCTAssertTrue(gpuArgs.contains("-pix_fmt"))
        XCTAssertTrue(gpuArgs.contains("nv12"))
        
        // Test CPU encoding arguments
        let cpuArgs = FilterBuilder.buildEncodingArguments(useGPU: false)
        XCTAssertTrue(cpuArgs.contains("-c:v"))
        XCTAssertTrue(cpuArgs.contains("libx264"))
        XCTAssertTrue(cpuArgs.contains("-pix_fmt"))
        XCTAssertTrue(cpuArgs.contains("yuv422p"))
    }
    
    func testFilterBuilderPreviewFilter() {
        let primaryLUT = "/test/primary.cube"
        let secondaryLUT = "/test/secondary.cube"
        
        // Test with primary LUT only
        let primaryOnlyResult = FilterBuilder.buildPreviewFilter(
            primaryLUTPath: primaryLUT,
            secondaryLUTPath: nil,
            opacity: 1.0
        )
        XCTAssertTrue(primaryOnlyResult.hasFilter)
        XCTAssertTrue(primaryOnlyResult.arguments.contains("-vf"))
        
        // Test with both LUTs
        let bothLUTsResult = FilterBuilder.buildPreviewFilter(
            primaryLUTPath: primaryLUT,
            secondaryLUTPath: secondaryLUT,
            opacity: 0.5
        )
        XCTAssertTrue(bothLUTsResult.hasFilter)
        XCTAssertTrue(bothLUTsResult.arguments.contains("-filter_complex"))
        
        // Test with no LUT
        let noLUTResult = FilterBuilder.buildPreviewFilter(
            primaryLUTPath: nil,
            secondaryLUTPath: nil,
            opacity: 1.0
        )
        XCTAssertFalse(noLUTResult.hasFilter)
    }
    
    func testConstants() {
        // Test FFmpeg constants
        XCTAssertEqual(FFmpegConstants.defaultBitrate, "140000k")
        XCTAssertEqual(FFmpegConstants.audioCodec, "aac")
        XCTAssertEqual(FFmpegConstants.audioBitrate, "192k")
        
        // Test UI constants
        XCTAssertEqual(UIConstants.statusTextFontSize, 12)
        XCTAssertEqual(UIConstants.defaultOpacity, 1.0)
        
        // Test file constants
        XCTAssertEqual(FileConstants.lutFileExtension, "cube")
        XCTAssertEqual(FileConstants.outputFileExtension, "mp4")
    }
}
