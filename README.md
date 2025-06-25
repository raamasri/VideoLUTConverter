# VideoLUTConverter

## Introduction
VideoLUTConverter is a macOS application designed for video professionals and content creators who need to quickly convert LOG footage from various sources, apply basic color corrections, and generate client-ready proofs with minimal effort. Built with Swift for the Mac App Store, it leverages FFmpeg and user-supplied LUTs for flexible, high-speed batch conversions.

## Use Cases
- **Batch Converting LOG Footage:** Quickly process multiple video files in series, applying LUTs for color correction and Rec.709 conversion, making it easy to prepare dailies or proofs for clients.
- **Flexible LUT Application:** Supports any camera or LOG format, as long as FFmpeg can process it. Users can load and layer up to two LUT files for creative or technical color grading.
- **Speedy Client Proofs:** Streamlines the process of converting and exporting footage, allowing for fast turnaround when sending previews or proofs to clients.

## Key Features
- **Universal LOG Support:** Works with any camera or LOG format supported by FFmpeg, thanks to user-supplied LUT files.
- **Layered LUTs:** Apply up to two LUTs in sequence for flexible color workflows.
- **Batch Processing:** Process any number of files in series, with both per-file and overall progress indicators.
- **Flexible Output:** Output format and color space depend on the LUT and FFmpeg capabilities, allowing for Rec.709 or other conversions as needed.
- **Minimal, Efficient UI:** Manual file loading (no drag-and-drop yet), focused on quick, minimal-interaction batch conversions.
- **macOS Only:** Built with Swift for the Mac App Store.

## Basic Usage
1. **Launch the App:** Open VideoLUTConverter on your Mac.
2. **Load Video Files:** Manually select the LOG footage you wish to convert.
3. **Select LUTs:** Choose up to two LUT files to apply in sequence. These can be technical or creative LUTs, depending on your workflow.
4. **Start Batch Conversion:** Begin processing. The app will process files one by one, showing both per-file and overall progress.
5. **Retrieve Output:** Converted files will be saved in the specified output location, in the format and color space determined by your LUT and FFmpeg settings.

## Requirements
- **Platform:** macOS (Swift-based, Mac App Store)
- **Dependencies:** FFmpeg (bundled with the app)
- **Input/Output:** Any format supported by FFmpeg

## Roadmap / Future Features
- Additional basic correction controls (exposure, contrast, white balance, etc.)
- Drag-and-drop file loading
- Expanded output options and presets

## License
Please ensure you comply with FFmpeg's licensing terms when distributing or using this application.

---

For questions or support, please contact the developer or open an issue on the repository. 