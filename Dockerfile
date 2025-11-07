FROM alpine:latest

# Install ffmpeg and required dependencies
RUN apk add --no-cache \
    ffmpeg \
    bash \
    tzdata \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy recording script
COPY record.sh /app/record.sh
RUN chmod +x /app/record.sh

# Set timezone (optional, adjust as needed)
ENV TZ=UTC

# Run the recording script
CMD ["/app/record.sh"]

