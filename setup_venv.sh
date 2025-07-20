#!/bin/bash
# Setup Python virtual environment for NVIDIA Nsight Systems profiling POC

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Python virtual environment for nsys profiling POC${NC}"
echo "============================================================="

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo -e "Python version: ${YELLOW}$python_version${NC}"

# Check if Python 3.7+ is available
required_version="3.7"
if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 7) else 1)" 2>/dev/null; then
    echo -e "${RED}Error: Python 3.7 or higher is required${NC}"
    exit 1
fi

# Create virtual environment
echo -e "\n${YELLOW}Creating virtual environment...${NC}"
python3 -m venv venv

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create virtual environment${NC}"
    echo "Make sure python3-venv is installed:"
    echo "  Ubuntu/Debian: sudo apt-get install python3-venv"
    echo "  RHEL/CentOS: sudo yum install python3-virtualenv"
    exit 1
fi

# Activate virtual environment
echo -e "${YELLOW}Activating virtual environment...${NC}"
source venv/bin/activate

# Upgrade pip
echo -e "\n${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip setuptools wheel

# Install requirements
echo -e "\n${YELLOW}Installing requirements...${NC}"
pip install -r requirements.txt

# Check NVTX installation
echo -e "\n${YELLOW}Checking NVTX installation...${NC}"
if python -c "import nvtx" 2>/dev/null; then
    echo -e "${GREEN}✓ NVTX installed successfully${NC}"
else
    echo -e "${YELLOW}⚠ NVTX installation failed (optional)${NC}"
    echo "  NVTX annotations will use dummy implementation"
fi

# Create activation reminder script
cat > activate_env.sh << 'EOF'
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
EOF

chmod +x activate_env.sh

# Display summary
echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Virtual environment created successfully!"
echo ""
echo "To activate the environment:"
echo -e "  ${YELLOW}source venv/bin/activate${NC}"
echo "Or use the helper script:"
echo -e "  ${YELLOW}source activate_env.sh${NC}"
echo ""
echo "To deactivate:"
echo -e "  ${YELLOW}deactivate${NC}"
echo ""
echo "Installed packages:"
pip list | grep -E "numpy|nvtx|aiofiles|matplotlib|pandas"
echo ""
echo -e "${GREEN}Ready to run profiling examples!${NC}"