#!/bin/bash
# Script to configure system for CPU profiling without sudo

echo "CPU Profiling Setup Script"
echo "========================="
echo ""

# Check current setting
CURRENT=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Current perf_event_paranoid level: $CURRENT"

if [ "$CURRENT" -le 1 ]; then
    echo "✓ CPU profiling is already enabled (level $CURRENT)"
    exit 0
fi

echo ""
echo "To enable CPU profiling without sudo, choose an option:"
echo ""
echo "1. Temporary (until reboot):"
echo "   sudo sh -c 'echo 1 > /proc/sys/kernel/perf_event_paranoid'"
echo ""
echo "2. Permanent (survives reboot):"
echo "   echo 'kernel.perf_event_paranoid = 1' | sudo tee -a /etc/sysctl.conf"
echo "   sudo sysctl -p"
echo ""
echo "3. Permanent (using sysctl.d - recommended):"
echo "   echo 'kernel.perf_event_paranoid = 1' | sudo tee /etc/sysctl.d/99-perf.conf"
echo "   sudo sysctl -p /etc/sysctl.d/99-perf.conf"
echo ""
echo "Note: Level 1 allows both kernel and user measurements (safe for development)"
echo "      Level -1 allows all events (less secure but maximum functionality)"
echo ""

# Ask user what to do
read -p "Apply temporary fix now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo 1 | sudo tee /proc/sys/kernel/perf_event_paranoid
    echo "✓ Temporary fix applied. CPU profiling should now work without sudo."
    echo ""
    echo "To make it permanent, run one of the commands shown above."
fi