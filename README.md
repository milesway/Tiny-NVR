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
- RTSP stream URL

## Quick Start

### Option 1: Using Docker Run (Simplest)

Pull and run directly from Docker Hub:

```bash
docker run -d \
  --name tiny-nvr \
  --restart unless-stopped \
  -e RTSP_URL=rtsp://your-camera-ip:554/stream \
  -v $(pwd)/recordings:/recordings \
  milesway6/tiny-nvr
```

**That's it!** The container will automatically pull from Docker Hub and start recording.

### Option 2: Using Docker Compose

1. **Create a `docker-compose.yml` file** (or use the provided one):
   ```yaml
   version: '3.8'

   services:
     tiny-nvr:
       image: milesway6/tiny-nvr
       container_name: tiny-nvr
       restart: unless-stopped
       environment:
         - RTSP_URL=rtsp://your-camera-ip:554/stream
         - SEGMENT_DURATION=1200
         - FILENAME_PATTERN=recording_%Y%m%d_%H%M%S.mp4
       volumes:
         - ./recordings:/recordings
         # Optional: Mount config.env for persistent configuration
         # - ./config.env:/app/config.env
   ```

   **Or use environment variables from your shell:**
   ```bash
   export RTSP_URL=rtsp://your-camera-ip:554/stream
   export SEGMENT_DURATION=1200
   docker-compose up -d
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

The recorder can be configured in three ways (in order of priority):

1. **Environment variables** (recommended for Docker)
2. **`/app/config.env` file** (editable inside container)
3. **`.env` file** (for local development)

### Configuration Options

Configure using environment variables:

- `RTSP_URL` **(required)**: Your RTSP stream URL (e.g., `rtsp://user:pass@192.168.1.100:554/stream`)
- `SEGMENT_DURATION`: Duration of each segment in seconds (default: `1200` = 20 minutes)
- `FILENAME_PATTERN`: Filename format using strftime patterns (default: `recording_%Y%m%d_%H%M%S.mp4`)
- `OUTPUT_DIR`: Output directory inside container (default: `/recordings` - mount this as a volume)
- `LOG_FILE`: Path to application log file (default: `/tmp/rtsp-recorder.log`)
- `FFMPEG_LOG_FILE`: Path to FFmpeg log file (default: `/tmp/ffmpeg.log`)

### Using config.env File

The `config.env` file is included in the Docker image and GitHub repository. You can edit it directly inside the container or mount it as a volume for persistent changes. See the "Editing Configuration Inside Container" section below for details.

### Example with All Options

```bash
docker run -d \
  --name tiny-nvr \
  --restart unless-stopped \
  -e RTSP_URL=rtsp://admin:password@192.168.1.100:554/stream1 \
  -e SEGMENT_DURATION=1800 \
  -e FILENAME_PATTERN=cam1_%Y%m%d_%H%M%S.mp4 \
  -v /path/to/recordings:/recordings \
  milesway6/tiny-nvr
```

### Updating Configuration

To change configuration, simply stop the container, update environment variables, and restart:

```bash
# Stop the container
docker stop tiny-nvr
docker rm tiny-nvr

# Start with new configuration
docker run -d \
  --name tiny-nvr \
  --restart unless-stopped \
  -e RTSP_URL=rtsp://new-camera-ip:554/stream \
  -e SEGMENT_DURATION=900 \
  -v $(pwd)/recordings:/recordings \
  milesway6/tiny-nvr
```

**Or with Docker Compose:**
```bash
# Edit docker-compose.yml or set environment variables
export RTSP_URL=rtsp://new-camera-ip:554/stream
docker-compose down
docker-compose up -d
```

### Editing Configuration Inside Container

You can login to the container, edit the configuration file, and restart the program:

```bash
# 1. Login to the container
docker exec -it tiny-nvr sh

# 2. Edit the configuration file
nano /app/config.env
# Or use vi: vi /app/config.env

# Example: Uncomment and edit lines in /app/config.env
# Change from:
#   # RTSP_URL=rtsp://example.com/stream
# To:
#   RTSP_URL=rtsp://your-camera-ip:554/stream

# Save and exit (in nano: Ctrl+X, then Y, then Enter)

# 3. Exit the container
exit

# 4. Restart the container to apply changes
docker restart tiny-nvr
```

**Note:** The `config.env` file is included in the Docker image at `/app/config.env` and is also available in the GitHub repository. Changes to this file inside the container are temporary and will be lost when the container is removed. For persistent configuration, either:
- Use environment variables (recommended)
- Mount a config file as a volume (see docker-compose.yml example below)

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
docker exec tiny-nvr cat /tmp/rtsp-recorder.log
docker exec tiny-nvr tail -f /tmp/rtsp-recorder.log
```

## Monitoring

- **View container status:**
  ```bash
  docker ps | grep tiny-nvr
  # Or with docker-compose:
  docker-compose ps
  ```

- **View logs:**
  ```bash
  docker logs -f tiny-nvr
  # Or with docker-compose:
  docker-compose logs -f
  ```

- **View container stats:**
  ```bash
  docker stats tiny-nvr
  ```

## Troubleshooting

### Connection Issues
- Ensure the RTSP URL is correct and accessible from the Docker host
- Check if the RTSP server requires authentication (include credentials in URL)
- Verify network connectivity: `docker exec tiny-nvr ping <rtsp-server-ip>`

### No Recordings
- Check logs: `docker logs tiny-nvr` (all logs include timestamps)
- Verify the recordings volume is mounted correctly: `docker inspect tiny-nvr | grep Mounts`
- Ensure the `recordings/` directory exists and has write permissions on the host
- Ensure the RTSP stream is active and accessible

### Permission Errors
- Ensure the `recordings/` directory has write permissions:
  ```bash
  mkdir -p recordings
  chmod 755 recordings/
  ```

### Stream Disconnections
The recorder automatically reconnects on stream failures. If disconnections persist:
- Check RTSP server stability
- Verify network reliability
- Consider using TCP transport (already enabled by default)

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Built with:
- [FFmpeg](https://ffmpeg.org/) - Multimedia framework
- [Docker](https://www.docker.com/) - Containerization platform
- [Alpine Linux](https://alpinelinux.org/) - Lightweight Linux distribution
