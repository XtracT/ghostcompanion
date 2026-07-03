#!/bin/bash
set -e

# One-shot mode (default): run GhostCompanion once and exit. Failures
# propagate so the container's restart policy can react.
if [ -z "$CRON_SCHEDULE" ]; then
  exec python ghostcompanion/main.py
fi

# Cron / service mode: CRON_SCHEDULE is set, so run continuously and
# execute GhostCompanion on the configured schedule.
# Strip surrounding quotes so that quoted values in .env/compose don't
# break the crontab (cron would see the quote char as a field).
CRON_SCHEDULE="${CRON_SCHEDULE#\"}"
CRON_SCHEDULE="${CRON_SCHEDULE%\"}"
CRON_SCHEDULE="${CRON_SCHEDULE#\'}"
CRON_SCHEDULE="${CRON_SCHEDULE%\'}"

echo "=========================================="
echo " Ghostcompanion entrypoint"
echo "   Container time : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "   CRON_SCHEDULE  : $CRON_SCHEDULE"
echo "=========================================="

# Run immediately on container start (don't fail the container if the job fails)
cd /app && python ghostcompanion/main.py || true

# Write crontab entry. Files in /etc/cron.d/ require a username field.
# Cron runs with a minimal environment and ignores the container's env
# vars (tokens, config) injected by compose/env_file. Dump the full
# environment so the scheduled job inherits everything.
{
  env
  echo "$CRON_SCHEDULE root cd /app && python ghostcompanion/main.py >> /proc/1/fd/1 2>&1"
  echo ""
} > /etc/cron.d/ghostcompanion
chmod 0644 /etc/cron.d/ghostcompanion

# Replace the shell with cron so it becomes PID 1 and handles signals correctly
exec cron -f
