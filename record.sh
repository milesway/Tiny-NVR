#!/bin/bash

# RTSP Stream Recorder Script
# Records RTSP stream in segments of specified duration

set -euo pipefail

# Load config file if it exists (priority: /app/config.env > .env)
# This allows users to edit /app/config.env inside the container
if [ -f "/app/config.env" ]; then
    set -a  # Automatically export all variables
    # shellcheck source=/dev/null
    . /app/config.env
    set +a  # Turn off automatic export
elif [ -f ".env" ]; then
    set -a  # Automatically export all variables
    # shellcheck source=/dev/null
    . .env
    set +a  # Turn off automatic export
fi

# Configuration from environment variables
RTSP_URL="${RTSP_URL:-rtsp://example.com/stream}"
SEGMENT_DURATION="${SEGMENT_DURATION:-1200}"  # 20 minutes in seconds (20 * 60)
OUTPUT_DIR="${OUTPUT_DIR:-/recordings}"
FILENAME_PATTERN="${FILENAME_PATTERN:-recording_%Y%m%d_%H%M%S.mp4}"
LOG_FILE="${LOG_FILE:-/tmp/rtsp-recorder.log}"
FFMPEG_LOG_FILE="${FFMPEG_LOG_FILE:-/tmp/ffmpeg.log}"

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Ensure log directory exists
mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "$(dirname "${FFMPEG_LOG_FILE}")"

# Log levels
readonly LOG_INFO="INFO"
readonly LOG_WARNING="WARNING"
readonly LOG_ERROR="ERROR"

# Robust log function with log levels and proper flushing
log() {
    local level="${1:-INFO}"
    shift
    local message="$*"
    local timestamp
    
    # Get timestamp, handle failures gracefully
    if ! timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
        timestamp="$(date +%s)"
    fi
    
    # Format log message
    local log_msg="[${timestamp}] [${level}] ${message}"
    
    # Output to stdout/stderr based on level
    if [ "${level}" = "${LOG_ERROR}" ]; then
        echo "${log_msg}" >&2
    else
        echo "${log_msg}"
    fi
    
    # Also write to log file if specified and writable
    if [ -n "${LOG_FILE}" ] && [ -w "$(dirname "${LOG_FILE}")" ] 2>/dev/null; then
        echo "${log_msg}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    
    # Force flush output buffers
    sync 2>/dev/null || true
}

# Log info message
log_info() {
    log "${LOG_INFO}" "$@"
}

# Log warning message
log_warning() {
    log "${LOG_WARNING}" "$@"
}

# Log error message
log_error() {
    log "${LOG_ERROR}" "$@"
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Validate RTSP URL format
    if [[ ! "${RTSP_URL}" =~ ^rtsp:// ]]; then
        log_error "Invalid RTSP URL format: ${RTSP_URL}"
        errors=$((errors + 1))
    fi
    
    # Validate segment duration (must be positive integer)
    if ! [[ "${SEGMENT_DURATION}" =~ ^[1-9][0-9]*$ ]]; then
        log_error "Invalid SEGMENT_DURATION: ${SEGMENT_DURATION} (must be positive integer)"
        errors=$((errors + 1))
    fi
    
    # Validate output directory is writable
    if [ ! -w "${OUTPUT_DIR}" ] 2>/dev/null; then
        log_error "Output directory is not writable: ${OUTPUT_DIR}"
        errors=$((errors + 1))
    fi
    
    # Check if ffmpeg is available
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_error "ffmpeg command not found"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Check available disk space (in MB)
check_disk_space() {
    local required_mb="${1:-100}"  # Default 100MB
    local available_mb
    
    if ! available_mb=$(df -m "${OUTPUT_DIR}" 2>/dev/null | awk 'NR==2 {print $4}'); then
        log_warning "Could not check disk space"
        return 0  # Assume OK if we can't check
    fi
    
    if [ "${available_mb}" -lt "${required_mb}" ]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    
    return 0
}

# Cleanup old log files (keep last N lines or files)
cleanup_logs() {
    local max_lines=10000
    local max_files=5
    
    # Rotate main log file if too large
    if [ -f "${LOG_FILE}" ] && [ -s "${LOG_FILE}" ]; then
        local line_count
        line_count=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo "0")
        if [ "${line_count}" -gt "${max_lines}" ]; then
            tail -n $((max_lines / 2)) "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null && \
            mv "${LOG_FILE}.tmp" "${LOG_FILE}" 2>/dev/null || true
            log_info "Rotated log file (kept last $((max_lines / 2)) lines)"
        fi
    fi
    
    # Rotate FFmpeg log file if too large
    if [ -f "${FFMPEG_LOG_FILE}" ] && [ -s "${FFMPEG_LOG_FILE}" ]; then
        local line_count
        line_count=$(wc -l < "${FFMPEG_LOG_FILE}" 2>/dev/null || echo "0")
        if [ "${line_count}" -gt "${max_lines}" ]; then
            tail -n $((max_lines / 2)) "${FFMPEG_LOG_FILE}" > "${FFMPEG_LOG_FILE}.tmp" 2>/dev/null && \
            mv "${FFMPEG_LOG_FILE}.tmp" "${FFMPEG_LOG_FILE}" 2>/dev/null || true
        fi
    fi
}

# Function to record a segment
record_segment() {
    local output_file
    local segment_start_time
    local segment_end_time
    local duration_actual
    
    # Create daily directory
    local daily_dir="${OUTPUT_DIR}/$(date +%Y-%m-%d)"
    
    if ! mkdir -p "${daily_dir}"; then
        log_error "Failed to create daily directory: ${daily_dir}"
        return 1
    fi

    # Generate output filename with timestamp
    if ! output_file="${daily_dir}/$(date +"${FILENAME_PATTERN}" 2>/dev/null)"; then
        log_error "Failed to generate output filename"
        return 1
    fi
    
    # Check disk space before recording (require at least 100MB)
    if ! check_disk_space 100; then
        log_warning "Skipping segment due to low disk space"
        return 1
    fi
    
    segment_start_time=$(date +%s)
    log_info "Starting new segment: ${output_file}"
    
    # Record with FFmpeg and add timestamps to output
    # Capture both stdout and stderr, add timestamps, and preserve exit code
    local ffmpeg_exit_code=1
    set +e  # Temporarily disable exit on error to capture exit code
    
    # Run ffmpeg with proper error handling
    # Note: Added timestamp handling flags to fix "Timestamps are unset" warning
    if ffmpeg \
        -y \
        -fflags +genpts+igndts \
        -rtsp_transport tcp \
        -analyzeduration 10000000 \
        -probesize 10000000 \
        -use_wallclock_as_timestamps 1 \
        -i "${RTSP_URL}" \
        -t "${SEGMENT_DURATION}" \
        -avoid_negative_ts make_zero \
        -c copy \
        -f mp4 \
        -movflags +faststart \
        -y \
        -loglevel warning \
        -err_detect ignore_err \
        -reconnect 1 \
        -reconnect_at_eof 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 2 \
        -timeout 5000000 \
        "${output_file}" 2>&1 | while IFS= read -r line || [ -n "${line:-}" ]; do
            # Only log non-empty lines
            if [ -n "${line:-}" ]; then
                local log_timestamp
                log_timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$(date +%s)")
                echo "[${log_timestamp}] FFmpeg: ${line}" | tee -a "${FFMPEG_LOG_FILE}" 2>/dev/null || true
            fi
        done; then
        ffmpeg_exit_code=0
    else
        ffmpeg_exit_code=${PIPESTATUS[0]}
    fi
    
    set -e  # Re-enable exit on error
    
    segment_end_time=$(date +%s)
    duration_actual=$((segment_end_time - segment_start_time))
    
    if [ ${ffmpeg_exit_code} -eq 0 ]; then
        # Verify file was created and has content
        if [ -f "${output_file}" ] && [ -s "${output_file}" ]; then
            local file_size
            # Try different stat commands for portability
            file_size=$(stat -c%s "${output_file}" 2>/dev/null || \
                       stat -f%z "${output_file}" 2>/dev/null || \
                       wc -c < "${output_file}" 2>/dev/null || \
                       echo "0")
            log_info "Segment completed successfully: ${output_file} (size: ${file_size} bytes, duration: ${duration_actual}s)"
            return 0
        else
            log_error "Segment file missing or empty: ${output_file}"
            return 1
        fi
    else
        log_error "FFmpeg failed with exit code ${ffmpeg_exit_code}: ${output_file}"
        # Clean up incomplete file
        [ -f "${output_file}" ] && rm -f "${output_file}" 2>/dev/null || true
        return 1
    fi
}

# Signal handler for graceful shutdown
cleanup() {
    log_info "Received shutdown signal, cleaning up..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main execution
main() {
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed. Exiting."
        exit 1
    fi
    
    # Log startup information
    log_info "=========================================="
    log_info "RTSP Recorder starting"
    log_info "RTSP URL: ${RTSP_URL}"
    log_info "Segment Duration: ${SEGMENT_DURATION} seconds ($(($SEGMENT_DURATION / 60)) minutes)"
    log_info "Output Directory: ${OUTPUT_DIR}"
    log_info "Filename Pattern: ${FILENAME_PATTERN}"
    log_info "Log File: ${LOG_FILE}"
    log_info "=========================================="
    
    # Cleanup old logs on startup
    cleanup_logs
    
    # Main recording loop
    local consecutive_failures=0
    local max_consecutive_failures=10
    
    while true; do
        # Periodic log cleanup (every 10 segments)
        if [ $((consecutive_failures % 10)) -eq 0 ]; then
            cleanup_logs
        fi
        
        if record_segment; then
            consecutive_failures=0
            # Small delay between segments to ensure clean file closure
            sleep 1
        else
            consecutive_failures=$((consecutive_failures + 1))
            log_warning "Recording failed (consecutive failures: ${consecutive_failures}/${max_consecutive_failures})"
            
            if [ ${consecutive_failures} -ge ${max_consecutive_failures} ]; then
                log_error "Too many consecutive failures (${consecutive_failures}). Waiting 30 seconds before retry..."
                sleep 30
                consecutive_failures=0  # Reset counter after long wait
            else
                sleep 5
            fi
        fi
    done
}

# Run main function
main "$@"
