# Tiny NVR - RTSP Stream Recorder

A lightweight, containerized RTSP stream recorder that automatically segments recordings into 20-minute files. Perfect for continuous surveillance recording with minimal resource usage.

## Features

- **Automatic Recording**: Continuously records RTSP streams without human intervention
- **Time-based Segmentation**: Creates a new file every 20 minutes (configurable)
- **Stable Operation**: Auto-reconnect on connection failures, restart policies
- **Unified Naming**: Consistent filename format using timestamps
- **Terminal Interface**: Simple command-line interface, no web UI
- **Lightweight**: Minimal Alpine-based container with FFmpeg
- **Zero Re-encoding**: Preserves original stream quality using codec copy
- **Robust Logging**: Comprehensive logging with levels (INFO, WARNING, ERROR), automatic log rotation, and timestamps
- **Error Handling**: Automatic recovery from failures, disk space monitoring, and validation

## Requirements

- Docker
- Docker Compose
- RTSP stream URL

## Quick Start

1. **Configure your RTSP stream:**
   ```bash
   # Edit .env and set your RTSP_URL
   nano .env
   ```

2. **Start the recorder:**
   ```bash
   docker-compose up -d
   ```

3. **View logs:**
   ```bash
   docker-compose logs -f
   ```

4. **Stop the recorder:**
   ```bash
   docker-compose down
   ```

## Configuration

Edit the `.env` file to configure:

- `RTSP_URL`: Your RTSP stream URL (e.g., `rtsp://user:pass@192.168.1.100:554/stream`)
- `SEGMENT_DURATION`: Duration of each segment in seconds (default: 1200 = 20 minutes)
- `FILENAME_PATTERN`: Filename format using strftime patterns (default: `recording_%Y%m%d_%H%M%S.mp4`)
- `LOG_FILE`: Path to application log file (default: `/tmp/rtsp-recorder.log`)
- `FFMPEG_LOG_FILE`: Path to FFmpeg log file (default: `/tmp/ffmpeg.log`)

### Filename Pattern Examples

The `FILENAME_PATTERN` uses strftime format strings:

- `recording_%Y%m%d_%H%M%S.mp4` → `recording_20240101_143022.mp4`
- `cam1_%Y-%m-%d_%H-%M-%S.mp4` → `cam1_2024-01-01_14-30-22.mp4`
- `stream_%Y%m%d_%H%M%S.ts` → `stream_20240101_143022.ts`

## Output

Recordings are saved to the `./recordings/` directory with filenames matching your configured pattern. Each file is a complete, playable MP4 segment.

Example output:
```
recordings/
├── recording_20240101_143022.mp4
├── recording_20240101_144222.mp4
├── recording_20240101_145422.mp4
└── ...
```

## Logging

The recorder includes robust logging with the following features:

- **Log Levels**: INFO, WARNING, and ERROR levels for better log filtering
- **Timestamps**: All log entries include precise timestamps
- **Automatic Rotation**: Log files are automatically rotated when they exceed 10,000 lines
- **Dual Output**: Logs are written to both stdout (for Docker logs) and log files
- **FFmpeg Logs**: Separate logging for FFmpeg output with timestamps

Log files are located at:
- Application logs: `/tmp/rtsp-recorder.log` (configurable via `LOG_FILE`)
- FFmpeg logs: `/tmp/ffmpeg.log` (configurable via `FFMPEG_LOG_FILE`)

View logs inside the container:
```bash
docker exec rtsp-recorder cat /tmp/rtsp-recorder.log
docker exec rtsp-recorder tail -f /tmp/rtsp-recorder.log
```

## Monitoring

- **View container status:**
  ```bash
  docker-compose ps
  ```

- **View logs:**
  ```bash
  docker-compose logs -f rtsp-recorder
  # Or with Docker timestamps:
  docker-compose logs -f -t rtsp-recorder
  ```

- **View container stats:**
  ```bash
  docker stats rtsp-recorder
  ```

## Troubleshooting

### Connection Issues
- Ensure the RTSP URL is correct and accessible from the Docker host
- Check if the RTSP server requires authentication (include credentials in URL)
- Verify network connectivity: `docker exec rtsp-recorder ping <rtsp-server-ip>`

### No Recordings
- Check logs: `docker-compose logs -t rtsp-recorder` (all logs include timestamps)
- Verify the `recordings/` directory exists and has write permissions
- Ensure the RTSP stream is active and accessible

### Permission Errors
- Ensure the `recordings/` directory has write permissions:
  ```bash
  chmod 755 recordings/
  ```

### Stream Disconnections
The recorder automatically reconnects on stream failures. If disconnections persist:
- Check RTSP server stability
- Verify network reliability
- Consider using TCP transport (already enabled by default)

## Technical Details

- **RTSP Transport**: TCP (more stable than UDP)
- **Video Format**: MP4 container with original codecs (no re-encoding)
- **Restart Policy**: `unless-stopped` (automatically restarts on failure)
- **Base Image**: Alpine Linux (minimal footprint)
- **Recording Method**: FFmpeg with segment duration limit
- **Error Recovery**: Automatic retry with exponential backoff after consecutive failures
- **Disk Space Monitoring**: Checks available disk space before recording (requires 100MB minimum)
- **File Validation**: Verifies recorded files exist and have content before marking as successful
- **Signal Handling**: Graceful shutdown on SIGTERM/SIGINT signals
- **Configuration Validation**: Validates all configuration parameters on startup

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Built with:
- [FFmpeg](https://ffmpeg.org/) - Multimedia framework
- [Docker](https://www.docker.com/) - Containerization platform
- [Alpine Linux](https://alpinelinux.org/) - Lightweight Linux distribution
