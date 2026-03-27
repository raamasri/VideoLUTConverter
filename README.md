# VideoLUTConverter

## Introduction
VideoLUTConverter is a macOS application designed for video professionals and content creators who need to quickly convert LOG footage from various sources, apply color corrections, and generate client-ready proofs with minimal effort. Built with Swift for the Mac App Store, it leverages FFmpeg and user-supplied LUTs for flexible, high-speed batch conversions.

## Use Cases
- **Batch Converting LOG Footage:** Quickly process multiple video files in series, applying LUTs for color correction and Rec.709 conversion, making it easy to prepare dailies or proofs for clients.
- **Flexible LUT Application:** Supports any camera or LOG format, as long as FFmpeg can process it. Users can load and layer up to two LUT files for creative or technical color grading.
- **Speedy Client Proofs:** Streamlines the process of converting and exporting footage, allowing for fast turnaround when sending previews or proofs to clients.

## Supported Formats
- **Apple Log** (iPhone 15 Pro and later) -- ProRes in MOV containers
- **Sony S-Log 3** -- XAVC S (H.264) and XAVC HS (H.265)
- **Sony S-Log 2** -- AVCHD and XAVC
- **Any other LOG format** supported by FFmpeg with a matching .cube LUT file

## Key Features
- **Universal LOG Support:** Works with any camera or LOG format supported by FFmpeg, using user-supplied .cube LUT files.
- **Dual LUT Layering:** Apply up to two LUTs with adjustable blend opacity for flexible color workflows -- a primary conversion LUT plus an optional creative LUT blended at any percentage.
- **White Balance Control:** Adjust color temperature from 2400K to 8000K with a real-time slider, applied on top of LUT corrections.
- **Live Preview:** See a frame preview with your LUT and white balance settings applied before committing to a full export.
- **Batch Processing:** Process any number of files in series, with both per-file and overall progress indicators.
- **GPU & CPU Encoding:** Toggle between hardware-accelerated VideoToolbox H.264 encoding (fast) and software libx264 lossless encoding (maximum quality).
- **Drag and Drop:** Drop video and LUT files directly onto the window to load them.
- **File Validation:** Videos and LUT files are validated before processing to catch issues early.
- **Flexible Output:** Output format and color space depend on the LUT and FFmpeg capabilities, supporting Rec.709 and other conversions.
- **macOS Native:** Built with Swift and AppKit, with Liquid Glass visual effects for macOS 26.

## Basic Usage
1. **Launch the App:** Open VideoLUTConverter on your Mac.
2. **Load Video Files:** Click "Load Videos" or drag and drop LOG footage onto the window.
3. **Select Primary LUT:** Choose a .cube LUT file for the base color conversion (e.g., S-Log3 to Rec.709).
4. **Optional -- Select Second LUT:** Add a creative LUT and adjust the blend opacity slider.
5. **Optional -- Adjust White Balance:** Use the white balance slider to fine-tune color temperature.
6. **Preview:** Check the live frame preview to verify your settings.
7. **Choose Encoding Mode:** Toggle between GPU (fast) and CPU (lossless) encoding.
8. **Export:** Click "Convert to Rec.709", select an output directory, and the batch conversion begins.

## Requirements
- **Platform:** macOS 11.0 or later
- **Dependencies:** FFmpeg (bundled with the app)
- **Input:** MOV, MP4, MKV, AVI, M4V, and other formats supported by FFmpeg
- **Output:** MP4 (H.264 + AAC)

## Technical Details
- GPU mode: `h264_videotoolbox` at 140 Mbps, High profile, Level 5.1
- CPU mode: `libx264` CRF 0 (lossless), veryslow preset, yuv422p
- Audio: AAC at 192 kbps (passthrough mapping)
- LUT application via FFmpeg `lut3d` filter with `blend` overlay for dual-LUT mixing

## License
Please ensure you comply with FFmpeg's licensing terms when distributing or using this application.

---

For questions or support, please contact the developer or open an issue on the repository.
