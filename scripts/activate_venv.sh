#!/bin/bash
# Helper script to ensure virtual environment is activated

# Function to check if we're in a virtual environment
in_virtualenv() {
    python -c 'import sys; print("1" if hasattr(sys, "real_prefix") or (hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix) else "0")'
}

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Creating it..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
elif [ "$(in_virtualenv)" = "0" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "Virtual environment is already active."
fi

# Export the Python command to use
export VENV_PYTHON="$(which python)"