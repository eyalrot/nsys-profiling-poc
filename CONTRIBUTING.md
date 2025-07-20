# Contributing to NVIDIA Nsight Systems CPU Profiling POC

Thank you for your interest in contributing to this project! This POC aims to demonstrate various CPU profiling techniques using NVIDIA Nsight Systems.

## How to Contribute

### Reporting Issues
- Use GitHub Issues to report bugs or suggest features
- Provide detailed information about your environment
- Include steps to reproduce any issues

### Adding Examples
New profiling examples are welcome! When adding examples:

1. **Python Examples**: Add to `python/` directory
   - Follow the naming pattern: `N_description.py`
   - Include docstrings and comments
   - Add NVTX annotations where appropriate

2. **C++ Examples**: Add to `cpp/` directory
   - Follow the naming pattern: `N_description.cpp`
   - Update the Makefile to include build rules
   - Use consistent coding style

3. **Update Documentation**
   - Add your example to README.md
   - Update MAKEFILE_GUIDE.md if adding new targets
   - Include example output or screenshots

### Improving Scripts
- Enhance profiling scripts in `scripts/`
- Add new analysis capabilities
- Improve visualization options

### Code Style
- Python: Follow PEP 8
- C++: Use consistent formatting (prefer clang-format)
- Shell scripts: Use shellcheck for validation

### Testing
Before submitting:
1. Run `make clean && make all`
2. Test with `make profile`
3. Verify `make analyze` works
4. Run `./test_environment.py`

### Pull Request Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd profiling-poc

# Set up Python environment
./setup_venv.sh
source venv/bin/activate

# Build C++ examples
make all

# Run tests
python test_environment.py
```

## Areas for Contribution

### High Priority
- GPU profiling examples
- MPI/distributed computing examples
- Real-world application examples
- Performance optimization guides

### Medium Priority
- Additional visualization options
- Integration with CI/CD pipelines
- Docker containerization
- Cross-platform support

### Nice to Have
- Jupyter notebook examples
- Web-based report viewer
- Automated performance regression testing
- Machine learning workload examples

## Questions?

Feel free to open an issue for discussion or contact the maintainers.