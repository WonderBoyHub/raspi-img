# Contributing to Pop-OS Raspberry Pi Image Builder

Thank you for your interest in contributing to the Pop-OS Raspberry Pi Image Builder! This document provides guidelines for contributing to the project.

## 🤝 How to Contribute

### Reporting Issues

1. **Search existing issues** first to avoid duplicates
2. **Use the issue template** when creating new issues
3. **Provide detailed information** including:
   - Platform (Pi 4 or Pi 5)
   - Operating system used for building
   - Error messages and logs
   - Steps to reproduce

### Submitting Changes

1. **Fork the repository** and create a feature branch
2. **Make your changes** following the coding standards
3. **Test your changes** thoroughly
4. **Submit a pull request** with a clear description

### Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/pop-os-raspi-builder.git
cd pop-os-raspi-builder

# Install dependencies
make deps

# Validate environment
make validate TARGET_PLATFORM=pi4
make validate TARGET_PLATFORM=pi5

# Build and test
make pi4  # or make pi5
```

## 📋 Coding Standards

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable strict error handling: `set -eE`
- Use meaningful variable names
- Add comments for complex logic
- Quote variables to prevent word splitting
- Use `local` for function variables

### Makefile

- Use tabs for indentation
- Add help text for new targets
- Use `.PHONY` for non-file targets
- Include error handling

### Documentation

- Use Markdown for documentation
- Include examples for complex procedures
- Keep README.md updated with new features
- Document any breaking changes

## 🔧 Platform Support

### Adding New Platforms

1. Create platform directory: `data/piX/`
2. Add platform-specific configurations
3. Update Makefile with new platform
4. Add platform validation
5. Update documentation

### Platform Structure

```
data/piX/
├── boot/firmware/
│   ├── config.txt      # Platform-specific config
│   ├── cmdline.txt     # Kernel command line
│   └── README          # Platform documentation
└── etc/                # Platform-specific system config
```

## 🧪 Testing

### Local Testing

```bash
# Test both platforms
make validate TARGET_PLATFORM=pi4
make validate TARGET_PLATFORM=pi5

# Test build process
make pi4
make pi5

# Test specific components
make info
make test
```

### CI/CD Testing

- All PRs trigger automated builds
- Both Pi 4 and Pi 5 images are built
- Basic validation tests are run
- Artifacts are uploaded for testing

## 📝 Documentation Requirements

### New Features

- Update README.md with new features
- Add usage examples
- Document any new configuration options
- Update help text in Makefile

### Bug Fixes

- Document the issue being fixed
- Include test cases if applicable
- Update troubleshooting guide if needed

## 🎯 Areas for Contribution

### High Priority

- **Performance optimization** - Reduce build times
- **Error handling** - Better error messages and recovery
- **Testing** - More comprehensive test coverage
- **Documentation** - Improve user guides and examples

### Medium Priority

- **Platform support** - Add support for other SBCs
- **Customization** - More configuration options
- **Automation** - Better CI/CD workflows
- **Monitoring** - Build health and metrics

### Low Priority

- **UI/UX** - Better user interface for configuration
- **Packaging** - Distribution packages
- **Integration** - Integration with other tools

## 🚀 Pull Request Guidelines

### Before Submitting

- [ ] Code follows project standards
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] No merge conflicts

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested on Pi 4
- [ ] Tested on Pi 5
- [ ] Added/updated tests
- [ ] Updated documentation

## Screenshots/Logs
If applicable, add screenshots or logs
```

## 📧 Communication

### Getting Help

- **GitHub Issues** - For bugs and feature requests
- **GitHub Discussions** - For questions and general discussion
- **Pull Requests** - For code review and collaboration

### Code Review Process

1. **Automated checks** run on all PRs
2. **Maintainer review** within 48 hours
3. **Community feedback** welcome
4. **Merge** after approval and passing tests

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the GPL-3.0 license.

## 🙏 Recognition

Contributors will be:
- Added to the project README
- Mentioned in release notes
- Given appropriate GitHub repository permissions

## 📚 Additional Resources

- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [Pop-OS Documentation](https://support.system76.com/articles/pop-overview)
- [Ubuntu ARM Documentation](https://ubuntu.com/download/raspberry-pi)
- [Debootstrap Manual](https://wiki.debian.org/Debootstrap)

---

Thank you for contributing to the Pop-OS Raspberry Pi Image Builder! 🎉 