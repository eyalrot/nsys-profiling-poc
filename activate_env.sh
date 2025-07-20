#!/bin/bash
# Quick activation script for the virtual environment

if [ -d "venv" ]; then
    source venv/bin/activate
    echo "Virtual environment activated!"
    echo "Python: $(which python)"
    echo "Pip: $(which pip)"
else
    echo "Error: venv directory not found!"
    echo "Run ./setup_venv.sh first"
fi
